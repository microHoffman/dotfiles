import argparse
import copy
import fcntl
import hashlib
import os
from pathlib import Path
import stat
import sys
import tempfile
import time
from collections.abc import Mapping, MutableMapping
from contextlib import contextmanager

import tomlkit


LOCK_TIMEOUT_SECONDS = 10
MAX_RETRIES = 5


class ReconcileError(Exception):
    pass


class TargetChanged(ReconcileError):
    pass


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Merge an authoritative TOML overlay into a mutable config."
        )
    )
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--lock", type=Path, required=True)
    parser.add_argument(
        "--delete-if-equals",
        action="append",
        default=[],
        nargs=2,
        metavar=("DOTTED_PATH", "TOML_VALUE"),
        help=(
            "delete a target value only when it still equals the supplied "
            "TOML value; may be repeated"
        ),
    )
    return parser.parse_args()


def read_regular_file(path, label):
    try:
        file_stat = path.lstat()
    except FileNotFoundError:
        raise ReconcileError(f"{label} does not exist: {path}") from None

    if stat.S_ISLNK(file_stat.st_mode) or not stat.S_ISREG(file_stat.st_mode):
        raise ReconcileError(f"{label} must be a regular file: {path}")

    try:
        return path.read_bytes(), file_stat
    except OSError as error:
        message = f"could not read {label}: {path}: {error}"
        raise ReconcileError(message) from error


def read_target(path):
    try:
        file_stat = path.lstat()
    except FileNotFoundError:
        return None, None

    if stat.S_ISLNK(file_stat.st_mode) or not stat.S_ISREG(file_stat.st_mode):
        raise ReconcileError(f"target must be a regular file: {path}")
    if file_stat.st_uid != os.geteuid():
        message = f"target is not owned by the current user: {path}"
        raise ReconcileError(message)

    try:
        return path.read_bytes(), file_stat
    except OSError as error:
        message = f"could not read target: {path}: {error}"
        raise ReconcileError(message) from error


def parse_toml(raw_content, path, label):
    try:
        return tomlkit.parse(raw_content.decode("utf-8"))
    except (UnicodeDecodeError, tomlkit.exceptions.ParseError) as error:
        message = f"invalid {label} TOML: {path}: {error}"
        raise ReconcileError(message) from error


def is_table(value):
    return isinstance(value, (Mapping, MutableMapping))


def merge_tables(target, source):
    changed = False
    for key, source_value in source.items():
        if key not in target:
            target[key] = copy.deepcopy(source_value)
            changed = True
            continue

        target_value = target[key]
        if is_table(target_value) and is_table(source_value):
            changed = merge_tables(target_value, source_value) or changed
        elif target_value != source_value:
            target[key] = copy.deepcopy(source_value)
            changed = True

    return changed


def normalize_toml_value(value):
    if hasattr(value, "unwrap"):
        value = value.unwrap()
    if is_table(value):
        return {
            key: normalize_toml_value(child)
            for key, child in value.items()
        }
    if isinstance(value, list):
        return [normalize_toml_value(child) for child in value]
    return value


def parse_delete_rules(raw_rules):
    rules = []
    for dotted_path, raw_value in raw_rules:
        keys = dotted_path.split(".")
        if any(not key for key in keys):
            raise ReconcileError(
                f"invalid delete-if-equals path: {dotted_path}"
            )
        try:
            document = tomlkit.parse(f"value = {raw_value}\n")
        except tomlkit.exceptions.ParseError as error:
            message = (
                "invalid delete-if-equals TOML value for "
                f"{dotted_path}: {error}"
            )
            raise ReconcileError(message) from error
        rules.append((keys, normalize_toml_value(document["value"])))
    return rules


def delete_matching_values(target, rules):
    changed = False
    for keys, expected_value in rules:
        current = target
        parents = []
        for key in keys[:-1]:
            if not is_table(current) or key not in current:
                break
            parents.append((current, key))
            current = current[key]
        else:
            leaf = keys[-1]
            if (
                is_table(current)
                and leaf in current
                and normalize_toml_value(current[leaf]) == expected_value
            ):
                del current[leaf]
                changed = True
                for parent, key in reversed(parents):
                    child = parent.get(key)
                    if is_table(child) and not child:
                        del parent[key]
                    else:
                        break
    return changed


def fingerprint(content):
    if content is None:
        return None
    return hashlib.sha256(content).digest()


def target_fingerprint(path):
    content, _ = read_target(path)
    return fingerprint(content)


def write_atomically(path, content, mode):
    descriptor = None
    temporary_path = None
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            dir=path.parent,
            prefix=f".{path.name}.dotfiles.",
        )
        temporary_path = Path(temporary_name)
        os.fchmod(descriptor, mode)
        with os.fdopen(descriptor, "wb") as temporary_file:
            descriptor = None
            temporary_file.write(content)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.replace(temporary_path, path)
        temporary_path = None

        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if descriptor is not None:
            os.close(descriptor)
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


@contextmanager
def exclusive_lock(path):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    flags = os.O_RDWR | os.O_CREAT | os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW

    try:
        descriptor = os.open(path, flags, 0o600)
    except OSError as error:
        message = f"could not open config lock: {path}: {error}"
        raise ReconcileError(message) from error

    deadline = time.monotonic() + LOCK_TIMEOUT_SECONDS
    try:
        while True:
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ReconcileError(
                        f"timed out waiting for config lock: {path}"
                    ) from None
                time.sleep(0.1)
        yield
    finally:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_UN)
        finally:
            os.close(descriptor)


def reconcile_once(source_document, target_path, delete_rules):
    original_content, target_stat = read_target(target_path)
    if original_content is None:
        target_document = tomlkit.document()
        mode = 0o600
    else:
        target_document = parse_toml(original_content, target_path, "target")
        mode = stat.S_IMODE(target_stat.st_mode)

    changed = merge_tables(target_document, source_document)
    changed = delete_matching_values(target_document, delete_rules) or changed
    if not changed:
        return False

    rendered = tomlkit.dumps(target_document).encode("utf-8")
    parse_toml(rendered, target_path, "merged")

    if target_fingerprint(target_path) != fingerprint(original_content):
        message = f"target changed during reconciliation: {target_path}"
        raise TargetChanged(message)

    write_atomically(target_path, rendered, mode)
    return True


def reconcile(source_path, target_path, lock_path, raw_delete_rules):
    source_content, _ = read_regular_file(source_path, "source")
    source_document = parse_toml(source_content, source_path, "source")
    delete_rules = parse_delete_rules(raw_delete_rules)

    target_path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with exclusive_lock(lock_path):
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                changed = reconcile_once(
                    source_document,
                    target_path,
                    delete_rules,
                )
                action = "Updated" if changed else "Unchanged"
                print(f"{action} managed config: {target_path}")
                return
            except TargetChanged:
                if attempt == MAX_RETRIES:
                    message = (
                        "target kept changing during reconciliation: "
                        f"{target_path}"
                    )
                    raise ReconcileError(message) from None


def main():
    args = parse_args()
    try:
        reconcile(
            args.source,
            args.target,
            args.lock,
            args.delete_if_equals,
        )
    except ReconcileError as error:
        print(f"reconcile-agent-config: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
