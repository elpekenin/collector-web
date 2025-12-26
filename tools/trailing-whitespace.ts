/// <reference types="bun-types" />

import { basename } from "node:path";

const main = async (args: string[]): Promise<number> => {
	if (args.length < 2) throw new Error("unreachable");

	const [_, this_file, ...params] = args;
	if (params.length === 0) {
		if (!this_file) throw new Error("unreachable");

		const exe = basename(this_file);
		Bun.stderr.write(`usage: bun ${exe} [files...]\n`);
		return 1;
	}

	const promises = params.map(async (filepath) => {
		const file = Bun.file(filepath);

		const text = await file.text();

		const lines = text.split("\n").map((line) => line.trimEnd());

		return file.write(lines.join("\n"));
	});

	await Promise.all(promises);

	return 0;
};

process.exit(await main(process.argv));
