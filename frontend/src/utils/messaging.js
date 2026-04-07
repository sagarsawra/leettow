/**
 * messaging.js â€” Promise wrappers around chrome.runtime.sendMessage.
 */

export function sendMessage(type, payload = {}) {
  return new Promise((resolve, reject) => {
    try {
      chrome.runtime.sendMessage({ type, payload }, (response) => {
        if (chrome.runtime.lastError) {
          reject(new Error(chrome.runtime.lastError.message));
          return;
        }
        if (!response?.success) {
          reject(new Error(response?.error ?? "Unknown error from background."));
          return;
        }
        resolve(response);
      });
    } catch (err) {
      reject(err);
    }
  });
}

export function isExtensionContext() {
  return typeof chrome !== "undefined" && !!chrome.runtime?.id;
}
