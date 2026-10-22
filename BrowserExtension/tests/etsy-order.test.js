const test = require("node:test");
const assert = require("node:assert/strict");
const {
  buildAppURL,
  findAddressInData,
  findItemsInData,
  findOrderIDInData,
  isCompleteAddress,
  parseAddressLines
} = require("../etsy-order.js");

test("parses a German shipping address block", () => {
  const address = parseAddressLines([
    "Versandadresse",
    "Mia Muster",
    "Hauptstraße 1",
    "Wohnung 2",
    "66740 Saarlouis",
    "Deutschland",
    "Adresse kopieren"
  ]);
  assert.deepEqual(address, {
    name: "Mia Muster",
    street1: "Hauptstraße 1",
    street2: "Wohnung 2",
    postalCode: "66740",
    city: "Saarlouis",
    state: "",
    country: "Deutschland"
  });
  assert.equal(isCompleteAddress(address), true);
});

test("finds order, address and items in nested Etsy data", () => {
  const data = {
    receipt: {
      receipt_id: 1234567890,
      shipping_address: {
        name: "Mia Muster",
        first_line: "Hauptstraße 1",
        second_line: "",
        zip: "66740",
        city: "Saarlouis",
        country_name: "Deutschland"
      },
      transactions: [
        { transaction_id: 44, title: "Schmuckschatulle", quantity: 2 }
      ]
    }
  };
  assert.equal(findOrderIDInData(data), "1234567890");
  assert.equal(findAddressInData(data).street1, "Hauptstraße 1");
  assert.deepEqual(findItemsInData(data), [{ title: "Schmuckschatulle", quantity: 2 }]);
});

test("builds a URL-safe app link with Unicode data", () => {
  const url = buildAppURL({
    version: 1,
    orderID: "123",
    recipient: {
      name: "Mia Müller",
      street1: "Hauptstraße 1",
      street2: "",
      postalCode: "66740",
      city: "Saarlouis",
      state: "",
      country: "Deutschland"
    },
    items: [{ title: "Größe L", quantity: 1 }],
    sourceURL: "https://www.etsy.com/your/orders/123"
  });
  assert.match(url, /^munbyn-labeler:\/\/etsy-order\?payload=[A-Za-z0-9_-]+$/);
});
