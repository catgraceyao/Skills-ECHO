const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying P1 contracts with account:", deployer.address);

  // Deploy MilestoneEscrow P1 (with PhaseTransition events)
  const MilestoneEscrow = await ethers.getContractFactory("MilestoneEscrow");
  const milestoneEscrow = await MilestoneEscrow.deploy(deployer.address);
  await milestoneEscrow.waitForDeployment();
  const milestoneAddress = await milestoneEscrow.getAddress();
  console.log("MilestoneEscrow P1 deployed to:", milestoneAddress);

  // P0 EdgeDeclaration address (keep existing)
  const edgeDeclarationAddress = "0xC54e1B665c61b2Dc9831dc5a1C4D22670bea3C4a";

  // Deploy DeadlockInspector P1
  const DeadlockInspector = await ethers.getContractFactory("DeadlockInspectorP1");
  const deadlockInspector = await DeadlockInspector.deploy(edgeDeclarationAddress);
  await deadlockInspector.waitForDeployment();
  const deadlockAddress = await deadlockInspector.getAddress();
  console.log("DeadlockInspector P1 deployed to:", deadlockAddress);
  console.log("EdgeDeclaration (P0, unchanged):", edgeDeclarationAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
