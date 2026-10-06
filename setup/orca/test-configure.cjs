const assert = require('node:assert/strict');
const { test } = require('node:test');
const { configure } = require('./configure.cjs');

function runtime(extraCommands = []) {
  const state = {
    settings: {
      disabledTuiAgents: ['claude', 'codex', 'other'],
      agentDefaultArgs: { other: '--keep' },
      agentDefaultEnv: { codex: { KEEP: 'yes' } },
    },
    commands: structuredClone(extraCommands),
    writes: 0,
  };
  return {
    state,
    async call(method, params) {
      switch (method) {
        case 'settings.get':
          return { result: { settings: structuredClone(state.settings) } };
        case 'settings.update':
          state.writes++;
          Object.assign(state.settings, params);
          return { result: { settings: state.settings } };
        case 'settings.getTerminalQuickCommands':
          return { result: { terminalQuickCommands: structuredClone(state.commands) } };
        case 'settings.updateTerminalQuickCommands': {
          state.writes++;
          assert.equal(params.mutation.type, 'upsert');
          const command = params.mutation.command;
          const index = state.commands.findIndex((entry) => entry.id === command.id);
          if (index < 0) state.commands.push(command);
          else state.commands[index] = command;
          return { result: { terminalQuickCommands: state.commands } };
        }
        default: throw new Error(`Unexpected method: ${method}`);
      }
    },
  };
}

test('profiles use native Codex flags and preserve user commands and environment on reruns', async () => {
  const custom = { id: 'user-command', label: 'Mine', command: 'echo preserved' };
  const client = runtime([custom]);
  await configure(client);
  await configure(client);
  assert.equal(client.state.commands.length, 9);
  assert.deepEqual(client.state.commands[0], custom);
  assert.deepEqual(client.state.commands.slice(1).map((entry) => entry.command), [
    'codex', 'codex --profile own', 'codex --profile seo', 'codex --profile sentry',
    'claude-profile default', 'claude-profile own', 'claude-profile seo', 'claude-profile sentry',
  ]);
  assert.deepEqual(client.state.settings.disabledTuiAgents, ['other']);
  assert.equal(client.state.settings.agentDefaultArgs.other, '--keep');
  assert.equal(client.state.settings.agentDefaultEnv.codex.KEEP, 'yes');
});

test('a full command list fails before changing settings', async () => {
  const client = runtime(Array.from({ length: 40 }, (_, n) => ({ id: `user-${n}` })));
  await assert.rejects(configure(client), /Not enough Quick Command slots/);
  assert.equal(client.state.writes, 0);
});
