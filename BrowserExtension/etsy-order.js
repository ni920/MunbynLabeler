(function exposeMunbynEtsy(root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  root.MunbynEtsy = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function createMunbynEtsy() {
  "use strict";

  const ADDRESS_LABELS = [
    "versandadresse",
    "lieferadresse",
    "empfänger",
    "empfaenger",
    "ship to",
    "shipping address",
    "delivery address",
    "deliver to"
  ];

  const IGNORED_LINES = new Set([
    ...ADDRESS_LABELS,
    "adresse kopieren",
    "copy address",
    "bearbeiten",
    "edit",
    "details"
  ]);

  function clean(value) {
    return String(value ?? "").replace(/\s+/g, " ").trim();
  }

  function normalizedKey(value) {
    return clean(value).toLowerCase().replace(/[^a-z0-9]/g, "");
  }

  function objectValue(object, aliases) {
    if (!object || typeof object !== "object" || Array.isArray(object)) return "";
    const wanted = new Set(aliases.map(normalizedKey));
    for (const [key, value] of Object.entries(object)) {
      if (!wanted.has(normalizedKey(key))) continue;
      if (["string", "number"].includes(typeof value)) return clean(value);
    }
    return "";
  }

  function walkJSON(value, visitor, path = [], depth = 0, seen = new Set()) {
    if (depth > 14 || value == null || typeof value !== "object" || seen.has(value)) return;
    seen.add(value);
    visitor(value, path);
    if (Array.isArray(value)) {
      value.slice(0, 250).forEach((entry, index) => walkJSON(entry, visitor, [...path, String(index)], depth + 1, seen));
      return;
    }
    Object.entries(value).slice(0, 250).forEach(([key, entry]) => {
      walkJSON(entry, visitor, [...path, key], depth + 1, seen);
    });
  }

  function addressFromObject(object) {
    const name = objectValue(object, ["recipient_name", "full_name", "buyer_name", "addressee", "name"]);
    const street1 = objectValue(object, ["first_line", "address_line_1", "address1", "street1", "street"]);
    const street2 = objectValue(object, ["second_line", "address_line_2", "address2", "street2"]);
    const city = objectValue(object, ["city", "locality", "town"]);
    const state = objectValue(object, ["state", "province", "region"]);
    const postalCode = objectValue(object, ["zip", "zip_code", "zipcode", "postal_code", "postalcode"]);
    const country = objectValue(object, ["country_name", "country", "country_iso", "countrycode"]);
    if (!name && !street1 && !city && !postalCode) return null;
    return { name, street1, street2, postalCode, city, state, country };
  }

  function addressScore(address, path) {
    let score = 0;
    if (address.name) score += 2;
    if (address.street1) score += 3;
    if (address.city) score += 2;
    if (address.postalCode) score += 3;
    if (address.country) score += 1;
    if (/(ship|delivery|recipient|address|buyer)/i.test(path.join("/"))) score += 6;
    return score;
  }

  function findAddressInData(data) {
    let best = null;
    let bestScore = 0;
    walkJSON(data, (value, path) => {
      if (Array.isArray(value)) return;
      const address = addressFromObject(value);
      if (!address) return;
      const score = addressScore(address, path);
      if (score > bestScore) {
        best = address;
        bestScore = score;
      }
    });
    return bestScore >= 8 ? best : null;
  }

  function findOrderIDInData(data) {
    let result = "";
    walkJSON(data, (value, path) => {
      if (result || Array.isArray(value)) return;
      const candidate = objectValue(value, ["receipt_id", "order_id", "orderid", "receiptid"]);
      if (candidate && /^\d{4,}$/.test(candidate) && /(receipt|order|transaction)/i.test(path.join("/"))) {
        result = candidate;
      }
    });
    return result;
  }

  function findItemsInData(data) {
    const items = [];
    const seen = new Set();
    walkJSON(data, (value, path) => {
      if (Array.isArray(value) || items.length >= 20) return;
      const pathText = path.join("/");
      if (!/(transaction|listing|lineitem|line_item|items)/i.test(pathText)) return;
      const title = objectValue(value, ["title", "listing_title", "product_name", "name"]);
      const quantityText = objectValue(value, ["quantity", "qty"]);
      const identity = objectValue(value, ["transaction_id", "listing_id", "product_id"]);
      if (!title || (!quantityText && !identity)) return;
      const quantity = Math.max(1, Number.parseInt(quantityText || "1", 10) || 1);
      const key = `${title.toLowerCase()}|${quantity}`;
      if (seen.has(key)) return;
      seen.add(key);
      items.push({ title, quantity });
    });
    return items;
  }

  function parseAddressLines(rawLines) {
    const lines = rawLines
      .map(clean)
      .filter(Boolean)
      .filter((line) => !IGNORED_LINES.has(line.toLowerCase()))
      .filter((line) => !/^(bestellung|order|receipt)\s*#/i.test(line));
    if (lines.length < 3) return null;

    let localityIndex = -1;
    let postalCode = "";
    let city = "";
    let state = "";

    for (let index = 1; index < lines.length; index += 1) {
      const line = lines[index];
      let match = line.match(/^(\d{4,6})\s+(.+)$/);
      if (match) {
        localityIndex = index;
        postalCode = match[1];
        city = clean(match[2]);
        break;
      }
      match = line.match(/^(.+?),?\s+([A-Z]{2})\s+(\d{5}(?:-\d{4})?)$/);
      if (match) {
        localityIndex = index;
        city = clean(match[1]);
        state = match[2];
        postalCode = match[3];
        break;
      }
      match = line.match(/^(.+?)\s+([A-Z]{1,2}\d[A-Z\d]?\s*\d[A-Z]{2})$/i);
      if (match) {
        localityIndex = index;
        city = clean(match[1]);
        postalCode = match[2].toUpperCase();
        break;
      }
    }

    if (localityIndex < 2) return null;
    const name = lines[0];
    const street1 = lines[1];
    const street2 = lines.slice(2, localityIndex).join(", ");
    const country = lines[localityIndex + 1] || "";
    return { name, street1, street2, postalCode, city, state, country };
  }

  function isCompleteAddress(address) {
    return Boolean(address && address.name && address.street1 && address.postalCode && address.city);
  }

  function jsonDocuments(document) {
    const documents = [];
    const scripts = document.querySelectorAll('script[type="application/json"], script[type="application/ld+json"], script[id*="data" i]');
    for (const script of scripts) {
      const text = script.textContent?.trim();
      if (!text || text.length > 5_000_000) continue;
      try {
        documents.push(JSON.parse(text));
      } catch (_) {
        // Etsy also ships non-JSON script blocks. They are intentionally ignored.
      }
    }
    return documents;
  }

  function addressFromDocument(document) {
    const labels = new Set(ADDRESS_LABELS);
    const candidates = document.querySelectorAll("h1,h2,h3,h4,h5,[role='heading'],dt,strong");
    for (const element of candidates) {
      const label = clean(element.textContent).toLowerCase().replace(/:$/, "");
      if (!labels.has(label)) continue;
      let container = element.parentElement;
      for (let level = 0; container && level < 5; level += 1, container = container.parentElement) {
        const lines = String(container.innerText || "").split(/\n+/);
        if (lines.length > 24) continue;
        const address = parseAddressLines(lines);
        if (isCompleteAddress(address)) return address;
      }
    }
    return null;
  }

  function itemsFromDocument(document) {
    const items = [];
    const seen = new Set();
    for (const link of document.querySelectorAll('a[href*="/listing/"]')) {
      const title = clean(link.getAttribute("aria-label") || link.textContent);
      if (!title || title.length < 3 || seen.has(title.toLowerCase())) continue;
      const containerText = clean(link.closest("li,article,[data-transaction-id],div")?.innerText || "");
      const quantityMatch = containerText.match(/(?:menge|quantity|qty)\s*:?\s*(\d+)/i);
      seen.add(title.toLowerCase());
      items.push({ title, quantity: Math.max(1, Number.parseInt(quantityMatch?.[1] || "1", 10)) });
      if (items.length >= 20) break;
    }
    return items;
  }

  function orderIDFromPage(url, text, dataDocuments) {
    for (const data of dataDocuments) {
      const result = findOrderIDInData(data);
      if (result) return result;
    }
    const parsed = new URL(url);
    const queryID = parsed.searchParams.get("order_id") || parsed.searchParams.get("receipt_id");
    if (queryID) return clean(queryID);
    const pathMatch = parsed.pathname.match(/(?:orders?|receipts?)\/(\d{4,})/i);
    if (pathMatch) return pathMatch[1];
    const textMatch = text.match(/\b(?:Bestellung|Order|Receipt)\s*#?\s*(\d{4,})/i);
    return textMatch?.[1] || "Unbekannt";
  }

  function extractOrder(document, url = document.location.href) {
    const documents = jsonDocuments(document);
    let recipient = null;
    let items = [];
    for (const data of documents) {
      if (!recipient) recipient = findAddressInData(data);
      if (items.length === 0) items = findItemsInData(data);
    }
    if (!isCompleteAddress(recipient)) recipient = addressFromDocument(document);
    if (items.length === 0) items = itemsFromDocument(document);

    return {
      version: 1,
      orderID: orderIDFromPage(url, String(document.body?.innerText || ""), documents),
      recipient: recipient || { name: "", street1: "", street2: "", postalCode: "", city: "", state: "", country: "" },
      items,
      sourceURL: url
    };
  }

  function base64URL(value) {
    const bytes = new TextEncoder().encode(value);
    let binary = "";
    for (const byte of bytes) binary += String.fromCharCode(byte);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
  }

  function buildAppURL(payload) {
    return `munbyn-labeler://etsy-order?payload=${base64URL(JSON.stringify(payload))}`;
  }

  return {
    buildAppURL,
    extractOrder,
    findAddressInData,
    findItemsInData,
    findOrderIDInData,
    isCompleteAddress,
    parseAddressLines
  };
});
