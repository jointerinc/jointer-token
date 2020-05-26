// It is broken because of structure change in the whiteList. Will updtae soon
const {
  constants,
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");
const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");

const whiteListContract = artifacts.require("WhiteList");
const WhiteListRegistry = artifacts.require("WhiteListRegistery");

contract("~WhiteList works", function (accounts) {
  const [
    primaryOwner,
    authorityAddress,
    systemAddress,
    toBeWhiteListed,
    extraAddedWallet,
    multiSigPlaceHolder,
    other1,
    other2,
  ] = accounts;
  var registryAddress;

  beforeEach(async function () {
    var whiteListRegistry = await WhiteListRegistry.new(
      systemAddress,
      multiSigPlaceHolder
    );
    let tempWhiteList = await whiteListContract.new();
    await whiteListRegistry.addVersion(1, tempWhiteList.address);
    await whiteListRegistry.createProxy(
      1,
      primaryOwner,
      systemAddress,
      authorityAddress
    );
    let proxyAddress = await whiteListRegistry.proxyAddress();
    this.whiteList = await whiteListContract.at(proxyAddress);
    registryAddress = whiteListRegistry.address;
  });
  it("should initialize properly", async function () {
    expect(await this.whiteList.primaryOwner()).to.equal(primaryOwner);
    expect(await this.whiteList.authorityAddress()).to.equal(authorityAddress);
    expect(await this.whiteList.systemAddress()).to.equal(systemAddress);
    expect(await this.whiteList.isAddressByPassed(registryAddress)).to.equal(
      true
    );
    expect(await this.whiteList.isAddressByPassed(systemAddress)).to.equal(
      true
    );
  });
  it("should set bypassed address correctly by system only", async function () {
    let bool = true;
    await this.whiteList.setByPassedAddress(toBeWhiteListed, bool, {
      from: systemAddress,
    });
    await expectRevert(
      this.whiteList.setByPassedAddress(toBeWhiteListed, true, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    expect(await this.whiteList.isAddressByPassed(toBeWhiteListed)).to.equal(
      bool
    );
  });
  it("should add New wallet correctly by system only", async function () {
    let whiteListType = 0;
    let maxWallets = 10;
    await expectRevert(
      this.whiteList.addNewWallet(toBeWhiteListed, whiteListType, maxWallets, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await expectRevert(
      this.whiteList.addNewWallet(ZERO_ADDRESS, whiteListType, maxWallets, {
        from: systemAddress,
      }),
      "ERR_ZERO_ADDRESS"
    );
    let receipt = await this.whiteList.addNewWallet(
      toBeWhiteListed,
      whiteListType,
      maxWallets,
      {
        from: systemAddress,
      }
    );

    expectEvent(receipt, "AccountWhiteListed", {
      which: toBeWhiteListed,
      walletType: whiteListType.toString(),
    });
    //Should add a reason in the solidity
    //it reverts because the wallet is already whitelisted
    await expectRevert.unspecified(
      this.whiteList.addNewWallet(toBeWhiteListed, whiteListType, maxWallets, {
        from: systemAddress,
      })
    );

    expect(await this.whiteList.is_whiteListed(toBeWhiteListed)).to.equal(true);
    expect(await this.whiteList.address_belongs(toBeWhiteListed)).to.equal(
      toBeWhiteListed
    );
    //can recieve
    expect(await this.whiteList.canReciveToken(toBeWhiteListed)).to.equal(true);
    //is WhiteListed
    expect(await this.whiteList.isWhiteListed(toBeWhiteListed)).to.equal(true);

    //details set correctly
    let details = await this.whiteList.user_details(toBeWhiteListed);
    expect(details.whiteListType.toString()).to.equal(whiteListType.toString());
    expect(details.maxWallets.toString()).to.equal(maxWallets.toString());
    expect(details.canRecive).to.equal(true);
  });
  it("should update max wallets correctly by owner only", async function () {
    let whiteListType = 0;
    let maxWallets = 10;
    let updatedMaxWallets = 1;
    await this.whiteList.addNewWallet(
      toBeWhiteListed,
      whiteListType,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await expectRevert(
      this.whiteList.updateMaxWallet(toBeWhiteListed, updatedMaxWallets, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    //cannot update if account is not whitelisted
    await expectRevert(
      this.whiteList.updateMaxWallet(other1, updatedMaxWallets, {
        from: systemAddress,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.updateMaxWallet(toBeWhiteListed, updatedMaxWallets, {
      from: primaryOwner,
    });
    let details = await this.whiteList.user_details(toBeWhiteListed);
    expect(details.maxWallets.toString()).to.equal(
      updatedMaxWallets.toString()
    );
  });
  it("should add more wallets correctly", async function () {
    let whiteListType = 0;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(
      toBeWhiteListed,
      whiteListType,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await expectRevert(
      this.whiteList.addMoreWallets(ZERO_ADDRESS, {
        from: toBeWhiteListed,
      }),
      "ERR_ZERO_ADDRESS"
    );
    await expectRevert(
      this.whiteList.addMoreWallets(extraAddedWallet, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );

    let receipt = await this.whiteList.addMoreWallets(extraAddedWallet, {
      from: toBeWhiteListed,
    });

    await expectRevert(
      this.whiteList.addMoreWallets(other1, {
        from: toBeWhiteListed,
      }),
      "ERR_MAXIMUM_WALLET_LIMIT"
    );
    expectEvent(receipt, "WalletAdded", {
      from: toBeWhiteListed,
      which: extraAddedWallet,
    });
    //how to get wallets???
    let userWallets = await this.whiteList.getUserWallets(toBeWhiteListed);
    expect(userWallets[0]).to.equal(extraAddedWallet);

    expect(await this.whiteList.address_belongs(extraAddedWallet)).to.equal(
      toBeWhiteListed
    );
    //can recieve
    expect(await this.whiteList.canReciveToken(extraAddedWallet)).to.equal(
      true
    );
    //is WhiteListed
    expect(await this.whiteList.isWhiteListed(extraAddedWallet)).to.equal(true);
  });
  it("should set expired walltes correctly by system only", async function () {
    let whiteListType = 0;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(
      toBeWhiteListed,
      whiteListType,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await expectRevert(
      this.whiteList.walletExpires(toBeWhiteListed, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.walletExpires(toBeWhiteListed, {from: systemAddress});
    //can recieve
    expect(await this.whiteList.canReciveToken(toBeWhiteListed)).to.equal(
      false
    );
  });
  it("should set wallet renewal correctly by system only", async function () {
    let whiteListType = 0;
    let maxWallets = 1;
    await this.whiteList.addNewWallet(
      toBeWhiteListed,
      whiteListType,
      maxWallets,
      {
        from: systemAddress,
      }
    );
    await expectRevert(
      this.whiteList.walletRenewed(toBeWhiteListed, {from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    await this.whiteList.walletExpires(toBeWhiteListed, {from: systemAddress});
    await this.whiteList.walletRenewed(toBeWhiteListed, {from: systemAddress});
    //can recieve
    expect(await this.whiteList.canReciveToken(toBeWhiteListed)).to.equal(true);
  });
  it("should set whitelist types to be allowed in primary correctly by system only", async function () {
    let whiteListTypes = [0, 3, 4, 5, 6];
    let setAllowedInPrimary = [false, true, true, true, true];
    let failingSizedwhiteListTypes = [0, 3, 4, 5, 6, 8];

    //the two arrays should be of same size
    await expectRevert.unspecified(
      this.whiteList.changeAllowInPrimary(
        failingSizedwhiteListTypes,
        setAllowedInPrimary,
        {
          from: systemAddress,
        }
      )
    );

    await this.whiteList.changeAllowInPrimary(
      whiteListTypes,
      setAllowedInPrimary,
      {
        from: systemAddress,
      }
    );
    for (let i = 0; i < whiteListTypes.length; i++) {
      expect(
        await this.whiteList.allowed_in_primary(whiteListTypes[i])
      ).to.equal(setAllowedInPrimary[i]);
    }
  });
  it("should set whitelist types to be allowed in secondary correctly by system only", async function () {
    let whiteListTypes = [0, 3, 4, 5, 6];
    let setAllowedInSecondary = [false, true, true, true, true];
    let failingSizedwhiteListTypes = [0, 3, 4, 5, 6, 8];

    //the two arrays should be of same size
    await expectRevert.unspecified(
      this.whiteList.changeAllowInSecondary(
        failingSizedwhiteListTypes,
        setAllowedInSecondary,
        {
          from: systemAddress,
        }
      )
    );

    await this.whiteList.changeAllowInSecondary(
      whiteListTypes,
      setAllowedInSecondary,
      {
        from: systemAddress,
      }
    );
    for (let i = 0; i < whiteListTypes.length; i++) {
      expect(
        await this.whiteList.allowed_in_secondary(whiteListTypes[i])
      ).to.equal(setAllowedInSecondary[i]);
    }
  });
});
