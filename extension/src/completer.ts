// src/completer.ts

import { CompleterModel, CompletionHandler } from '@jupyterlab/completer';

/**
 * Patches the CompleterModel to ensure the `resolve` function on a completion
 * item is not deleted after its first use. This allows documentation to be
 * re-fetched every time an item is selected.
 */
export function applyCompleterPatch(): void {
  // Store the original `resolveItem` function.
  const originalResolveItem = CompleterModel.prototype.resolveItem;

  // Replace it with our wrapped version.
  CompleterModel.prototype.resolveItem = function (
    this: CompleterModel,
    indexOrValue: number | CompletionHandler.ICompletionItem
  ): Promise<CompletionHandler.ICompletionItem | null> | undefined {
    // Find the item to be resolved
    let processedItem: CompletionHandler.ICompletionItem | undefined;
    if (typeof indexOrValue === 'number') {
      const items = this.completionItems();
      if (!items || !items[indexOrValue]) {
        return undefined;
      }
      processedItem = items[indexOrValue];
    } else {
      processedItem = indexOrValue;
    }

    // Find the original, unprocessed item that holds the real `resolve` function.
    let originalItem: CompletionHandler.ICompletionItem | undefined;
    const map = (this as any)._processedToOriginalItem as WeakMap<any, any>;
    if (map) {
      originalItem = map.get(processedItem);
    } else {
      originalItem = processedItem;
    }

    if (!originalItem) {
      return undefined;
    }

    // Temporarily store the `resolve` function if it exists.
    const originalResolve = originalItem.resolve;

    // Call the original function. This will fetch the documentation
    // and then delete `originalItem.resolve`.
    const promise = originalResolveItem.call(this, indexOrValue);

    // After the original function has finished, restore the `resolve` function.
    if (promise && originalResolve) {
      promise
        .then(resolvedItem => {
          if (resolvedItem && originalItem && !originalItem.resolve) {
            originalItem.resolve = originalResolve;
          }
        })
        .catch(() => {
          if (originalItem && !originalItem.resolve) {
            originalItem.resolve = originalResolve;
          }
        });
    }

    return promise;
  };
}