const hre = require("hardhat");

const PRICE_FEED = "0x694AA1769357215DE4FAC081bf1f309aDC325306"

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const PriceConverter = await hre.ethers.getContractFactory("PriceConverter");
  const priceConverter = await PriceConverter.deploy();
  await priceConverter.waitForDeployment();
  console.log("PriceConverter address:", priceConverter.address);

  const Crowdfunding = await hre.ethers.getContractFactory("Crowdfunding");
  const crowdfunding = await Crowdfunding.deploy(PRICE_FEED);
  await crowdfunding.waitForDeployment();
  console.log("Crowdfunding address:", crowdfunding.address);
}


main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
