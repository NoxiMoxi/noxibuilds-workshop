# Modules

The Intro tier teaches the habit that matters first: hand a small wish to a bot, then wait for one digest. Stay there while each wish still fits one slice.

When a wish outgrows one slice, add modules in this order.

1. **[claude-code-loop](claude-code-loop/MODULE.md)** slices a large wish into micro-slices and builds them one at a time. This is the first add.
2. **[journey-keeper](journey-keeper/MODULE.md)** comes with that loop. It keeps large slices honest against the user's journey, word for word.
3. **[codegraph](codegraph/MODULE.md)** maps real code, such as JavaScript, TypeScript, or Python, so later bots read a small pack. It is free, it needs no key, and a cloud agent can install it. A simple HTML page gets little from it.
4. **[redteam](redteam/MODULE.md)** reviews the result in sliced adversarial passes before a go-live.
5. **[lab-monitor](lab-monitor/MODULE.md)** wards the local build machine: folders, services, ports, and the loop install.

Each module has a `MODULE.md`: what it adds, what it needs, what it replaces, how a bot enables it, how to turn it off, the files, and a changelog. Role index for the advanced bots: [roles.md](roles.md).

Enabling a module creates the one bot that module describes. It does not replace the Intro Manager or Build Watcher until you decide the wish is too big for them. Turn a module off by retiring that bot and stopping the trigger it added. Do not leave a timer behind.
