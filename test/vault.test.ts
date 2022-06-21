import hre, { ethers } from "hardhat"
import {Contract, Signer, utils} from "ethers"

describe('Vault', function() {
  let signer: Signer;
  let erc20: Contract;
  before(async function() {
    [signer] = await ethers.getSigners();
  })
  beforeEach(async function() {
    let factory = await ethers.getContractFactory(
      'MockERC20',
      signer,
    );
    erc20 = await factory.deploy('test', 'TE', 18);
  })
  it('template test', async function() {
    // test logic
    await erc20.testLog();
  })
})