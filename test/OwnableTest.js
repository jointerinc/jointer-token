const {
  constants,
  expectEvent,
  expectRevert,
} = require("@openzeppelin/test-helpers");
const {ZERO_ADDRESS} = constants;

const {expect} = require("chai");

const Ownable = artifacts.require("Ownable");

contract("~Ownable works", function (accounts) {
  const [
    primaryOwner,
    authorityAddress,
    systemAddress,
    newAuthorityAddress,
    other,
    other1,
  ] = accounts;

  beforeEach(async function () {
    this.ownable = await Ownable.new(systemAddress, authorityAddress, {
      from: primaryOwner,
    });
  });

  it("should set the values correctly", async function () {
    expect(await this.ownable.primaryOwner()).to.equal(primaryOwner);
    expect(await this.ownable.authorityAddress()).to.equal(authorityAddress);
    expect(await this.ownable.systemAddress()).to.equal(systemAddress);
  });

  it("changes PrimaryOwner only by authority", async function () {
    const receipt = await this.ownable.changePrimaryOwner(other, {
      from: authorityAddress,
    });
    expectEvent(receipt, "OwnershipTransferred", {
      ownerType: "PRIMARY_OWNER",
      previousOwner: primaryOwner,
      newOwner: other,
    });

    await expectRevert(
      this.ownable.changePrimaryOwner(other, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    expect(await this.ownable.primaryOwner()).to.equal(other);
  });

  it("changes system only by authority", async function () {
    const receipt = await this.ownable.changeSystemAddress(other, {
      from: authorityAddress,
    });
    expectEvent(receipt, "OwnershipTransferred", {
      ownerType: "SYSTEM_ADDRESS",
      previousOwner: systemAddress,
      newOwner: other,
    });

    await expectRevert(
      this.ownable.changeSystemAddress(other, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    expect(await this.ownable.systemAddress()).to.equal(other);
  });

  it("changes Authority address only by authority", async function () {
    await this.ownable.changeAuthorityAddress(other, {
      from: authorityAddress,
    });
    expect(await this.ownable.newAuthorityAddress()).to.equal(other);
    await expectRevert(
      this.ownable.changeAuthorityAddress(other, {
        from: other1,
      }),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
  });
  it("new authority accepts correctly", async function () {
    await this.ownable.changeAuthorityAddress(other, {
      from: authorityAddress,
    });
    expectRevert(
      this.ownable.acceptAuthorityAddress({from: other1}),
      "ERR_AUTHORIZED_ADDRESS_ONLY"
    );
    let receipt = await this.ownable.acceptAuthorityAddress({from: other});
    expectEvent(receipt, "OwnershipTransferred", {
      ownerType: "AUTHORITY_ADDRESS",
      previousOwner: authorityAddress,
      newOwner: other,
    });
    expect(await this.ownable.authorityAddress()).to.equal(other);
  });
});
