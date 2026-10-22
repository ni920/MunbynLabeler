(function installMunbynButton() {
  "use strict";

  const ROOT_ID = "munbyn-labeler-extension-root";
  let toastTimer;

  function showToast(shadow, message, kind = "info") {
    const toast = shadow.querySelector(".munbyn-toast");
    toast.textContent = message;
    toast.dataset.kind = kind;
    toast.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.hidden = true; }, 5_000);
  }

  function sendCurrentOrder(shadow, button) {
    const order = globalThis.MunbynEtsy.extractOrder(document, location.href);
    if (!globalThis.MunbynEtsy.isCompleteAddress(order.recipient)) {
      showToast(shadow, "Empfängeradresse nicht gefunden. Bitte zuerst die Bestelldetails mit der Versandadresse öffnen.", "error");
      return;
    }

    button.disabled = true;
    button.querySelector("span").textContent = "Wird übertragen …";
    showToast(shadow, `Bestellung #${order.orderID} wird in Munbyn Labeler geöffnet.`, "success");
    location.href = globalThis.MunbynEtsy.buildAppURL(order);
    setTimeout(() => {
      button.disabled = false;
      button.querySelector("span").textContent = "An Munbyn Labeler senden";
    }, 1_500);
  }

  function render() {
    if (document.getElementById(ROOT_ID) || !document.body) return;
    const host = document.createElement("div");
    host.id = ROOT_ID;
    host.setAttribute("aria-label", "Munbyn Labeler Etsy-Erweiterung");
    const shadow = host.attachShadow({ mode: "open" });
    shadow.innerHTML = `
      <style>
        :host { all: initial; }
        .munbyn-wrap {
          position: fixed;
          right: 22px;
          bottom: 22px;
          z-index: 2147483647;
          display: grid;
          justify-items: end;
          gap: 10px;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .munbyn-button {
          appearance: none;
          border: 1px solid rgba(255,255,255,.22);
          border-radius: 10px;
          background: #202124;
          color: #fff;
          box-shadow: 0 8px 24px rgba(0,0,0,.2);
          cursor: pointer;
          display: inline-flex;
          align-items: center;
          gap: 9px;
          padding: 11px 15px;
          font: 600 14px/1.2 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .munbyn-button:hover { background: #101112; }
        .munbyn-button:focus-visible { outline: 3px solid rgba(38, 132, 255, .55); outline-offset: 2px; }
        .munbyn-button:disabled { cursor: wait; opacity: .72; }
        .munbyn-icon { width: 18px; height: 18px; flex: none; }
        .munbyn-toast {
          box-sizing: border-box;
          max-width: 360px;
          border: 1px solid #d8d8d8;
          border-radius: 9px;
          background: #fff;
          color: #222;
          box-shadow: 0 8px 24px rgba(0,0,0,.16);
          padding: 10px 12px;
          font: 500 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
        }
        .munbyn-toast[data-kind="error"] { border-color: #c94b44; }
        .munbyn-toast[data-kind="success"] { border-color: #3d8a53; }
      </style>
      <div class="munbyn-wrap">
        <div class="munbyn-toast" role="status" aria-live="polite" hidden></div>
        <button class="munbyn-button" type="button">
          <svg class="munbyn-icon" viewBox="0 0 24 24" aria-hidden="true">
            <path fill="currentColor" d="M6 3h12v5h1a3 3 0 0 1 3 3v6h-4v4H6v-4H2v-6a3 3 0 0 1 3-3h1V3Zm2 2v3h8V5H8Zm0 10v4h8v-4H8Zm10-4a1 1 0 1 0 0 2 1 1 0 0 0 0-2Z"/>
          </svg>
          <span>An Munbyn Labeler senden</span>
        </button>
      </div>`;
    const button = shadow.querySelector(".munbyn-button");
    button.addEventListener("click", () => sendCurrentOrder(shadow, button));
    document.body.appendChild(host);
  }

  render();
  const observer = new MutationObserver(() => {
    if (!document.getElementById(ROOT_ID)) render();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
})();
