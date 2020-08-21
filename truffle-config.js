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

const MNEMONIC = ["0x961309332f06b62acd4b950fc0cf77ab38723e8af47f88735764ed4b7d8c6924",
                  "0x1fb8b5f4f70f9d3c6ab130a53b56fb129f7bd91311d1665f95b83f343b7ab1f3",
                  "0xbdd95786b4e22f5bc317e87d1068e6820702e03ac971c43a398038dd6409707c",
                  "0xecb8e658f4a90a45f3b978f29e5f7bb6ce7457328d6c748a99e3d34643387450"];

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
        return new HDWalletProvider(MNEMONIC,"https://ropsten.infura.io/v3/708ba26d4eab49ecad5d3b4dd2f4b347");
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
      coinmarketcap: "705ed8e9-cb41-4081-8005-8bffa83dadda",
    },
  },
};
