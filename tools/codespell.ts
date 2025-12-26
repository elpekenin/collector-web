/// <reference types="bun-types" />

import { basename } from "node:path";

const main = (args: string[]): number => {
	if (args.length < 2) throw new Error("unreachable");

	const [_bun, this_file, ...params] = args;
	if (params.length === 0) {
		if (!this_file) throw new Error("unreachable");

		const exe = basename(this_file);
		Bun.stderr.write(`usage: bun ${exe} [files...]\n`);
		return 1;
	}

	const codespell = Bun.which("codespell");
	if (!codespell) {
		Bun.stderr.write("codespell was not found in $PATH\n");
		return 1;
	}

	return (
		Bun.spawn([codespell, ...params], { stdout: "inherit", stderr: "inherit" })
			.exitCode || 0
	);
};

process.exit(main(process.argv));
