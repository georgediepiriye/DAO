const { ethers } = require("hardhat");
const { FIGHTPUNKS_NFT_CONTRACT_ADDRESS } = require("../constants");

async function main() {
  // Deploy the FakeNFTMarketplace contract first
  const FakeNFTMarketplace = await ethers.getContractFactory(
    "FakeNFTMarketplace"
  );
  const fakeNftMarketplace = await FakeNFTMarketplace.deploy();
  await fakeNftMarketplace.deployed();

  console.log("FakeNFTMarketplace deployed to: ", fakeNftMarketplace.address);

  // deploy the FightPunksDAO contract
  const FightPunksDAO = await ethers.getContractFactory("FightPunksDAO");
  const fightPunksDAO = await FightPunksDAO.deploy(
    fakeNftMarketplace.address,
    FIGHTPUNKS_NFT_CONTRACT_ADDRESS,
    {
      // This assumes your account has at least 1 ETH in it's account
      // Change this value as you want
      value: ethers.utils.parseEther("0.01"),
    }
  );
  await fightPunksDAO.deployed();

  console.log("FightPunksDAO deployed to: ", fightPunksDAO.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
