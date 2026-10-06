// Use the pinned release's authenticated local RPC client, not its mutable profile files.
const commands = [
  ['default', 'Codex · Default', 'codex'],
  ['own', 'Codex · OWN', 'codex --profile own'],
  ['seo', 'Codex · SEO', 'codex --profile seo'],
  ['sentry', 'Codex · Sentry', 'codex --profile sentry'],
].map(([name, label, command]) => ({
  id: `dotfiles-codex-${name}`,
  label,
  command,
  action: 'terminal-command',
  appendEnter: true,
  scope: { type: 'global' },
})).concat(['default', 'own', 'seo', 'sentry'].map((name) => ({
  id: `dotfiles-claude-${name}`,
  label: `Claude · ${name === 'default' ? 'Default' : name.toUpperCase()}`,
  command: `claude-profile ${name}`,
  action: 'terminal-command',
  appendEnter: true,
  scope: { type: 'global' },
})));

async function configure(client) {
  const { result: { terminalQuickCommands: existing } } =
    await client.call('settings.getTerminalQuickCommands');
  const missing = commands.filter((command) => !existing.some((item) => item.id === command.id));
  if (existing.length + missing.length > 40) {
    throw new Error('Not enough Quick Command slots for the eight agent profile shortcuts');
  }
  const { result: { settings: current } } = await client.call('settings.get');
  await client.call('settings.update', {
    defaultTuiAgent: 'codex',
    agentStatusHooksEnabled: true,
    disabledTuiAgents: (current.disabledTuiAgents ?? []).filter(
      (agent) => !['codex', 'claude'].includes(agent),
    ),
    agentDefaultArgs: { ...current.agentDefaultArgs, codex: '', claude: '' },
    agentDefaultEnv: {
      ...current.agentDefaultEnv,
      codex: { ...current.agentDefaultEnv?.codex },
      claude: { ...current.agentDefaultEnv?.claude },
    },
  });
  const { result: { settings: saved } } = await client.call('settings.get');
  if (saved.defaultTuiAgent !== 'codex' || saved.agentDefaultArgs?.codex !== '' ||
      saved.agentDefaultArgs?.claude !== '' || saved.agentStatusHooksEnabled !== true) {
    throw new Error('Orca did not retain the requested agent defaults');
  }
  // Upsert only our stable IDs. Never replace the host's whole command list.
  for (const command of commands) {
    await client.call('settings.updateTerminalQuickCommands', {
      mutation: { type: 'upsert', command },
    });
  }
  const { result: { terminalQuickCommands: savedCommands } } =
    await client.call('settings.getTerminalQuickCommands');
  for (const command of commands) {
    const savedCommand = savedCommands.find((item) => item.id === command.id);
    if (!savedCommand || savedCommand.command !== command.command ||
        savedCommand.label !== command.label || savedCommand.scope?.type !== 'global' ||
        savedCommand.appendEnter !== true || savedCommand.action !== 'terminal-command') {
      throw new Error(`Orca did not retain the Quick Command ${command.label}`);
    }
  }
  console.log('Orca configured: Codex default, Manual launch arguments, agent status hooks enabled.');
  console.log('Quick Commands saved on this host: Codex Default, OWN, SEO, Sentry.');
  console.log('Claude Quick Commands: Default, OWN, SEO, Sentry (native Claude presets).');
  console.log('Claude is available without logging in; authenticate it only when you want to use it.');
}

module.exports = { configure };

if (require.main === module) {
  const path = require('node:path');
  const { RuntimeClient } = require(path.join(
    process.env.ORCA_CONFIGURE_APP_DIR,
    'resources/app.asar.unpacked/out/cli/runtime/client.js',
  ));
  // Explicit nulls prevent ambient ORCA_ENVIRONMENT/PAIRING_CODE from targeting another host.
  configure(new RuntimeClient(undefined, 10000, null, null)).catch((error) => {
    console.error(`orca-configure: ${error.message}`);
    process.exitCode = 1;
  });
}
