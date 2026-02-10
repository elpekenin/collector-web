/// <reference types="bun-types" />

import { basename, relative } from "node:path";

const main = (args: string[]): number => {
	if (args.length < 2) throw new Error("unreachable");

	const [_bun, this_file, ...params] = args;
	if (params.length === 0) {
		if (!this_file) throw new Error("unreachable");

		const exe = basename(this_file);
		Bun.stderr.write(`usage: bun ${exe} [files...]\n`);
		return 1;
	}

	const typos = Bun.which("typos");
	if (!typos) {
		Bun.stderr.write("typos was not found in $PATH\n");
		return 1;
	}

	const git_root = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"])
		.stdout.toString()
		.split("\n")[0];

	if (!git_root) {
		console.error("no git root");
		return 1;
	}

	// --force-exclude makes sure the whitelist in typos.toml is used
	// otherwise, files being passed on CLI takes precedence over config
	return Bun.spawnSync(
		[
			typos,
			"--force-exclude",
			...params.map((param) => relative(git_root, param)),
		],
		{
			stdout: "inherit",
			stderr: "inherit",
		},
	).exitCode;
};

process.exit(main(process.argv));
