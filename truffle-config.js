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

const MNEMONIC = [];

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
        return new HDWalletProvider(MNEMONIC,"");
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
