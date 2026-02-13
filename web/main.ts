import { init, jsz } from "ziex/wasm";

const importObject: WebAssembly.Imports = {
	"collector-web": {
		startAwaiting: (promiseId: number, out: number): void => {
			const exports = wasm?.instance.exports;
			if (!exports) return;

			const onPromiseCompleted = exports.onPromiseCompleted as (
				promiseId: number,
				success: boolean,
			) => void;

			const promise: Promise<object> = jsz.loadValue(promiseId);

			promise
				.then((value) => {
					jsz.storeValue(out, value);
					onPromiseCompleted(promiseId, true);
				})
				.catch((reason) => {
					jsz.storeValue(out, reason);
					onPromiseCompleted(promiseId, false);
				});
		},
	},
};

let wasm: WebAssembly.WebAssemblyInstantiatedSource | null = null;

init({
	importObject,
}).then((result) => {
	wasm = result.source;
});
