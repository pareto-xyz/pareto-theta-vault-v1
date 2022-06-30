import hre, { ethers } from "hardhat";
import { constants, Wallet } from "ethers";
import { parseWei } from "web3-units";
import { fromBn, toBn } from "evm-bn";
import { createFixtureLoader, MockProvider } from "ethereum-waffle";

import PrimitiveFactoryArtifact from "@primitivefi/rmm-core/artifacts/contracts/PrimitiveFactory.sol/PrimitiveFactory.json";
import PrimitiveEngineArtifact from "@primitivefi/rmm-core/artifacts/contracts/PrimitiveEngine.sol/PrimitiveEngine.json";
import PrimitiveManagerArtifact from "@primitivefi/rmm-manager/artifacts/contracts/PrimitiveManager.sol/PrimitiveManager.json";

import { computeEngineAddress } from "./utils";

/**
 * @notice Prepares Primitive contracts prior to running any tests. Future tests
 * will have access to the contracts.
 * @param description is a description of the test
 * @param runTests is a callback to run other tests
 */
export function runTest(description: string, runTests: Function): void {
  describe(description, function () {
    beforeEach(async function () {
      const wallets = await hre.ethers.getSigners();
      // three special roles: deployer (owner), keeper, and fee recipient
      const [deployer, alice, keeper, feeRecipient] = wallets;
      const loadFixture = createFixtureLoader(wallets as unknown as Wallet[]);
      const loadedFixture = await loadFixture(fixture);

      this.contracts = {
        vaultManager: loadedFixture.vaultManager,
        primitiveFactory: loadedFixture.primitiveFactory,
        primitiveEngine: loadedFixture.primitiveEngine,
        primitiveManager: loadedFixture.primitiveManager,
        aggregatorV3: loadedFixture.aggregatorV3,
        swapRouter: loadedFixture.swapRouter,
        weth: loadedFixture.weth,
        risky: loadedFixture.risky,
        stable: loadedFixture.stable,
      };

      this.wallets = {
        deployer,
        keeper,
        feeRecipient,
        alice
      };
    });

    runTests(); // callback function
  });
}

export async function fixture(
  [deployer, alice]: Wallet[],
  provider: MockProvider
) {
  // Create and deploy PrimitiveFactory
  const PrimitiveFactory = await ethers.getContractFactory(
    PrimitiveFactoryArtifact.abi,
    PrimitiveFactoryArtifact.bytecode,
    deployer
  );
  const primitiveFactory = await PrimitiveFactory.deploy();

  // Create ERC20 for risky and stable tokens
  const MockERC20 = await ethers.getContractFactory("MockERC20", deployer);
  const risky = await MockERC20.deploy();
  const stable = await MockERC20.deploy();

  await primitiveFactory.deploy(risky.address, stable.address);

  // Create and deploy the PrimitiveEngine
  const engineAddress = computeEngineAddress(
    primitiveFactory.address,
    risky.address,
    stable.address,
    PrimitiveEngineArtifact.bytecode
  );
  const primitiveEngine = await ethers.getContractAt(
    PrimitiveEngineArtifact.abi,
    engineAddress,
    deployer
  );

  // Create and deploy a WETH token
  const Weth = await ethers.getContractFactory("WETH9", deployer);
  const weth = await Weth.deploy();

  // Create and deploy the PrimitiveManager
  const PrimitiveManager = await ethers.getContractFactory(
    PrimitiveManagerArtifact.abi,
    PrimitiveManagerArtifact.bytecode,
    deployer
  );
  const primitiveManager = await PrimitiveManager.deploy(
    primitiveFactory.address,
    weth.address,
    weth.address
  );

  // Create and deploy Mock Chainlink protocol
  const AggregatorV3 = await ethers.getContractFactory(
    "MockAggregatorV3",
    deployer
  );
  const aggregatorV3 = await AggregatorV3.deploy();
  const decimals = await aggregatorV3.decimals();
  // initialize as equal prices
  aggregatorV3.setLatestAnswer(parseWei("1", decimals).raw);

  // Create and deploy Mock Uniswap router
  const SwapRouter = await ethers.getContractFactory(
    "MockSwapRouter",
    deployer
  );
  const swapRouter = await SwapRouter.deploy();

  // Create and deploy Pareto Manager protocol
  const ParetoManager = await ethers.getContractFactory(
    "ParetoManager",
    deployer
  );

  const vaultManager = await ParetoManager.deploy(
    110,
    risky.address,
    stable.address,
    aggregatorV3.address,
    false
  );

  // Mint tokens for address
  await risky.mint(deployer.address, parseWei("1000000").raw);
  await stable.mint(deployer.address, parseWei("1000000").raw);
  await risky.mint(alice.address, parseWei("1000000").raw);
  await stable.mint(alice.address, parseWei("1000000").raw);
  await risky.mint(primitiveManager.address, parseWei("1000000").raw);
  await stable.mint(primitiveManager.address, parseWei("1000000").raw);

  return {
    primitiveFactory,
    primitiveEngine,
    primitiveManager,
    weth,
    risky,
    stable,
    aggregatorV3,
    swapRouter,
    vaultManager,
  };
}
