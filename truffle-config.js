/*
 * NB: since truffle-hdwallet-provider 0.0.5 you must wrap HDWallet providers in a
 * function when declaring them. Failure to do so will cause commands to hang. ex:
 * ```
 * mainnet: {
 *     provider: function() {
 *       return new HDWalletProvider(mnemonic, 'https://mainnet.infura.io/<infura-key>')
 *     },
 *     network_id: '1',
 *     gas: 4500000,
 *     gasPrice: 10000000000,
 *   },
 */

var HDWalletProvider = require("@truffle/hdwallet-provider");

const MNEMONIC = ["0xd60d4f2e6873414f903c647dfe05a65d8bd5debfa4c2215ca8e87b2c6668b9f9",
                  "0x10a3e5949df0b2da79328d6469a059d64ac60bb0d3d1c18292510242126a1acb",
                  "0x60170ad983c27e73ab31efa678efc2a90dbb1fd2efc75b3c2677985d83fbaa87",
                  "0x3d62939fe6276f92600063c1fa71fbefa647f4ea23f8bd72cb1d07964df026ff"];

module.exports = {
  compilers: {
    solc: {
      version: "0.5.9",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*",
    },
    ropsten: {
      provider: function () {
        return new HDWalletProvider(MNEMONIC,"https://ropsten.infura.io/v3/9931db810af34f0a9875f87b89327f87");
      },
      network_id: "3",
      gas: 8000000,
      gasPrice: 100000000000,
      timeoutBlocks: 200,
      skipDryRun: true,
    },
  },
  mocha: {
    reporter: "eth-gas-reporter",
    reporterOptions: {
      currency: "USD",
      coinmarketcap: "",
    },
  },
};
