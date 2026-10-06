// Use the pinned release's authenticated local RPC client, not its mutable profile files.
const path = require('node:path');
const { RuntimeClient } = require(path.join(
  process.env.ORCA_CONFIGURE_APP_DIR,
  'resources/app.asar.unpacked/out/cli/runtime/client.js',
));

async function main() {
  // Explicit nulls prevent ambient ORCA_ENVIRONMENT/PAIRING_CODE from targeting another host.
  const client = new RuntimeClient(undefined, 10000, null, null);
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
  console.log('Orca configured: Codex default, Manual launch arguments, agent status hooks enabled.');
  console.log('Claude is available without logging in; authenticate it only when you want to use it.');
}

main().catch((error) => {
  console.error(`orca-configure: ${error.message}`);
  process.exitCode = 1;
});
