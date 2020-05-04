const {
  constants,
  expectEvent,
  expectRevert,
  BN,
} = require("@openzeppelin/test-helpers");

const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");

const advanceTime = (time) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.send(
      {
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [time],
        id: new Date().getTime(),
      },
      (err, result) => {
        if (err) {
          return reject(err);
        }
        return resolve(result);
      }
    );
  });
};

const jntrToken = artifacts.require("MainToken");
const stockToken = artifacts.require("StockToken");
const etnToken = artifacts.require("EtnToken");
const CurrencyPrices = artifacts.require("CurrencyPrices");
const AuctionRegisty = artifacts.require("AuctionRegistery");
const whiteListContract = artifacts.require("MockWhiteList");

contract("~System works", function (accounts) {
  var JntrToken;
  var StockToken;
  var EtnToken;

  const [
    primaryOwner,
    systemAddress,
    authorityAddress,
    returnTokenPlaceHolder,
    mutliSigAddressPlaceHolder,
    accountA,
    accountB,
    accountC,
    registryAddress,
    vault,
  ] = accounts;

  const etnName = "EtnToken";
  const etnSymbol = "ETN";
  const stockName = "StockToken";
  const stockSymbol = "STOCK";
  const jntrName = "JntrToken";
  const jntrSymbol = "JNTR";

  const etnTokenPrice = 1000000; //1$
  const JntrTokenPrice = 10000; //0.01$
  const stockTokenPrice = 10000000; //10$

  const stockTokenMaturityDays = 3560;
  const tokenMaturityDays = 0;
  const tokenHoldBackDays = 90;
  var accountAAmountJntr = 100000;
  var accountBAmountJntr = 50000;

  var accountAAmountStock = 2;
  var amountOfStockTokenSent = 1;
  var transferAmount = 10;
  var approvedAmount = 10;
  var amountOfJntrSent = 10000;

  beforeEach(async function () {
    // let now = (await web3.eth.getBlockNumber("latest")).timestamp;
    // console.log(now);

    this.auctionRegistery = await AuctionRegisty.new(
      systemAddress,
      mutliSigAddressPlaceHolder,
      {from: primaryOwner}
    );
    //setup WhiteList
    let whiteListType = 0;
    let maxWallets = 10;
    this.whiteList = await whiteListContract.new(registryAddress);
    await this.whiteList.initialize(
      primaryOwner,
      systemAddress,
      authorityAddress,
      {
        from: registryAddress,
      }
    );
    await this.whiteList.addNewWallet(accountA, whiteListType, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(accountB, whiteListType, maxWallets, {
      from: systemAddress,
    });
    await this.whiteList.addNewWallet(vault, whiteListType, maxWallets, {
      from: systemAddress,
    });
    //add currencyPrices
    this.currencyPrices = await CurrencyPrices.new({from: primaryOwner});

    //add addresses to the auctionRegistery
    this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("CURRENCY"),
      this.currencyPrices.address,
      {
        from: primaryOwner,
      }
    );
    this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("WHITE_LIST"),
      this.whiteList.address,
      {
        from: primaryOwner,
      }
    );
    this.auctionRegistery.registerContractAddress(
      web3.utils.fromAscii("VAULT"),
      vault,
      {
        from: primaryOwner,
      }
    );
    //The JNTR token

    JntrToken = await jntrToken.new(
      jntrName,
      jntrSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      JntrTokenPrice,
      tokenMaturityDays, //maturityDays
      tokenHoldBackDays,
      [accountA, accountB],
      [accountAAmountJntr, accountBAmountJntr],
      {
        from: primaryOwner,
      }
    );
    StockToken = await stockToken.new(
      stockName,
      stockSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      stockTokenPrice,
      stockTokenMaturityDays, //maturityDays
      tokenHoldBackDays,
      returnTokenPlaceHolder,
      [accountA],
      [accountAAmountStock],
      {
        from: primaryOwner,
      }
    );
    EtnToken = await etnToken.new(
      etnName,
      etnSymbol,
      systemAddress,
      authorityAddress,
      this.auctionRegistery.address,
      etnTokenPrice,
      tokenMaturityDays, //maturityDays
      tokenHoldBackDays,
      returnTokenPlaceHolder,
      {
        from: primaryOwner,
      }
    );

    //set currency prices
    await this.currencyPrices.setCurrencyPriceUSD(
      [StockToken.address],
      [stockTokenPrice],
      {from: primaryOwner}
    );
    await this.currencyPrices.setCurrencyPriceUSD(
      [JntrToken.address],
      [JntrTokenPrice],
      {from: primaryOwner}
    );
    await this.currencyPrices.setCurrencyPriceUSD(
      [EtnToken.address],
      [etnTokenPrice],
      {from: primaryOwner}
    );
  });
  describe("System should be  initialized correctly", async function () {
    it("has a name", async function () {
      expect(await StockToken.name()).to.equal(stockName);
      expect(await JntrToken.name()).to.equal(jntrName);
      expect(await EtnToken.name()).to.equal(etnName);
    });

    it("has a symbol", async function () {
      expect(await StockToken.symbol()).to.equal(stockSymbol);
      expect(await JntrToken.symbol()).to.equal(jntrSymbol);
      expect(await EtnToken.symbol()).to.equal(etnSymbol);
    });

    it("has 18 decimals", async function () {
      expect(await StockToken.decimals()).to.be.bignumber.equal("18");
      expect(await JntrToken.decimals()).to.be.bignumber.equal("18");
      expect(await EtnToken.decimals()).to.be.bignumber.equal("18");
    });
    it("should premint correctly", async function () {
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountStock.toString()
      );
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountJntr.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        accountBAmountJntr.toString()
      );
    });
  });

  describe("JNTR token should work correctly ", async function () {
    it("should transfer correctly", async function () {
      //before holdback days are over it should fail
      await expectRevert(
        JntrToken.transfer(accountB, transferAmount, {from: accountA}),
        "ERR_ACTION_NOT_ALLOWED"
      );

      await advanceTime(86400 * tokenHoldBackDays);

      let receipt = await JntrToken.transfer(accountB, 10, {from: accountA});
      await expectRevert(
        JntrToken.transfer(accountC, transferAmount, {from: accountA}),
        "ERR_TRANSFER_CHECK_WHITELIST"
      );
      //TODO check for events
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - transferAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + transferAmount).toString()
      );
    });
    it("should approve and transferFrom correctly", async function () {
      // await advanceTime(86400 * tokenHoldBackDays);

      await JntrToken.approve(accountB, approvedAmount, {from: accountA});
      expect(
        await JntrToken.allowance(accountA, accountB)
      ).to.be.bignumber.equal(approvedAmount.toString());

      await expectRevert(
        JntrToken.transferFrom(accountA, accountB, approvedAmount, {
          from: accountB,
        }),
        "ERR_ACTION_NOT_ALLOWED"
      );
      await advanceTime(86400 * tokenHoldBackDays);
      await expectRevert(
        JntrToken.transferFrom(accountA, accountC, approvedAmount, {
          from: accountB,
        }),
        "ERR_TRANSFER_CHECK_WHITELIST"
      );
      await JntrToken.transferFrom(accountA, accountB, approvedAmount, {
        from: accountB,
      });
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - approvedAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + approvedAmount).toString()
      );
    });
  });
  describe("StockToken should work correctly", async function () {
    it("should be able to buy tokens", async function () {
      //transferFrom of Jntr won't work if tokenHoldbackDays are not over
      await advanceTime(86400 * tokenHoldBackDays);
      //modifier of buytokens
      await StockToken.setExchangeableToken(JntrToken.address, {
        from: systemAddress,
      });
      await JntrToken.approve(StockToken.address, amountOfJntrSent, {
        from: accountB,
      });
      await StockToken.buyTokens(JntrToken.address, amountOfJntrSent, {
        from: accountB,
      });
      let amountOfStockTokens =
        (amountOfJntrSent * JntrTokenPrice) / stockTokenPrice;
      expect(await StockToken.balanceOf(accountB)).to.be.bignumber.equal(
        amountOfStockTokens.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr - amountOfJntrSent).toString()
      );
    });
  });
  describe("EthnToken should work correctly", async function () {
    it("should be able to buy tokens", async function () {
      //transferFrom of Stock won't work if tokenHoldbackDays are not over

      await advanceTime(86400 * tokenHoldBackDays);
      //modifier of buytokens
      await EtnToken.setExchangeableToken(StockToken.address, {
        from: systemAddress,
      });
      await StockToken.approve(EtnToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      await EtnToken.buyTokens(StockToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      let amountOfEtnTokens =
        (amountOfStockTokenSent * stockTokenPrice) / etnTokenPrice;
      expect(await EtnToken.balanceOf(accountA)).to.be.bignumber.equal(
        amountOfEtnTokens.toString()
      );
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountStock - amountOfStockTokenSent).toString()
      );
    });
  });
  describe("Entire Flow works", async function () {
    it("should log absolute values for brevity", async function () {
      //premint balances
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountStock.toString()
      );
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        accountAAmountJntr.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        accountBAmountJntr.toString()
      );
      await advanceTime(86400 * tokenHoldBackDays);
      //JNTR transfer
      await JntrToken.transfer(accountB, transferAmount, {from: accountA});

      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - transferAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + transferAmount).toString()
      );
      accountAAmountJntr = accountAAmountJntr - transferAmount;
      accountBAmountJntr = accountBAmountJntr + transferAmount;
      //JNTR transferfrom
      await JntrToken.approve(accountB, approvedAmount, {from: accountA});
      expect(
        await JntrToken.allowance(accountA, accountB)
      ).to.be.bignumber.equal(approvedAmount.toString());
      await JntrToken.transferFrom(accountA, accountB, approvedAmount, {
        from: accountB,
      });
      expect(await JntrToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountJntr - approvedAmount).toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr + approvedAmount).toString()
      );
      accountAAmountJntr = accountAAmountJntr - approvedAmount;
      accountBAmountJntr = accountBAmountJntr + approvedAmount;
      //buy Stock
      await StockToken.setExchangeableToken(JntrToken.address, {
        from: systemAddress,
      });
      await JntrToken.approve(StockToken.address, amountOfJntrSent, {
        from: accountB,
      });
      await StockToken.buyTokens(JntrToken.address, amountOfJntrSent, {
        from: accountB,
      });
      let amountOfStockTokens =
        (amountOfJntrSent * JntrTokenPrice) / stockTokenPrice;
      expect(await StockToken.balanceOf(accountB)).to.be.bignumber.equal(
        amountOfStockTokens.toString()
      );
      expect(await JntrToken.balanceOf(accountB)).to.be.bignumber.equal(
        (accountBAmountJntr - amountOfJntrSent).toString()
      );
      //buy ETN
      await EtnToken.setExchangeableToken(StockToken.address, {
        from: systemAddress,
      });

      await StockToken.approve(EtnToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      await EtnToken.buyTokens(StockToken.address, amountOfStockTokenSent, {
        from: accountA,
      });
      let amountOfEtnTokens =
        (amountOfStockTokenSent * stockTokenPrice) / etnTokenPrice;
      expect(await EtnToken.balanceOf(accountA)).to.be.bignumber.equal(
        amountOfEtnTokens.toString()
      );
      expect(await StockToken.balanceOf(accountA)).to.be.bignumber.equal(
        (accountAAmountStock - amountOfStockTokenSent).toString()
      );
      console.log("accountA\n");

      console.log(
        "StockToken\t" + (await StockToken.balanceOf(accountA)).toString()
      );
      console.log(
        "JntrToken\t" + (await JntrToken.balanceOf(accountA)).toString()
      );
      console.log(
        "EtnToken\t" + (await EtnToken.balanceOf(accountA)).toString()
      );

      console.log("\naccountB\n");

      console.log(
        "StockToken\t" + (await StockToken.balanceOf(accountB)).toString()
      );
      console.log(
        "JntrToken\t" + (await JntrToken.balanceOf(accountB)).toString()
      );
      console.log(
        "EtnToken\t" + (await EtnToken.balanceOf(accountB)).toString()
      );
    });
  });
});
