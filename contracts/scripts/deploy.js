const hre = require('hardhat');

/**
 * ECHO 青铜大使合约 Hardhat 部署脚本 v0.1
 * 
 * 使用方式:
 * 1. npm install
 * 2. npx hardhat compile
 * 3. export PRIVATE_KEY=你的私钥
 * 4. npx hardhat run scripts/deploy.js --network qng
 */

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log(`🚀 部署者: ${deployer.address}`);
  
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log(`💰 余额: ${hre.ethers.formatEther(balance)} MEER`);
  
  // 1. 部署 BronzeAmbassadorConfig
  console.log('\n📄 1. 部署 BronzeAmbassadorConfig...');
  const BronzeConfig = await hre.ethers.getContractFactory('BronzeAmbassadorConfig');
  const bronzeConfig = await BronzeConfig.deploy();
  await bronzeConfig.waitForDeployment();
  console.log(`   ✅ 地址: ${await bronzeConfig.getAddress()}`);
  
  // 2. 部署 IncentiveDistributor
  console.log('\n📄 2. 部署 IncentiveDistributor...');
  const FEE_COLLECTOR = process.env.FEE_COLLECTOR || deployer.address;
  const IncentiveDistributor = await hre.ethers.getContractFactory('IncentiveDistributor');
  const incentive = await IncentiveDistributor.deploy(
    await bronzeConfig.getAddress(),
    FEE_COLLECTOR
  );
  await incentive.waitForDeployment();
  console.log(`   ✅ 地址: ${await incentive.getAddress()}`);
  
  // 3. 部署 SnapshotRecorder
  console.log('\n📄 3. 部署 SnapshotRecorder...');
  const AGENT_JURY = '0x8b8F8B8f354b4D09c659E6c287a7258A728fb72D';
  const GOVERNANCE_DAO = '0x07E0FFCA344f846B499C811CE3127F5f3BFAd0b7';
  const SnapshotRecorder = await hre.ethers.getContractFactory('SnapshotRecorder');
  const snapshot = await SnapshotRecorder.deploy(AGENT_JURY, GOVERNANCE_DAO);
  await snapshot.waitForDeployment();
  console.log(`   ✅ 地址: ${await snapshot.getAddress()}`);
  
  // 4. 验证参数
  console.log('\n🔍 验证 BronzeAmbassadorConfig 参数...');
  const core = await bronzeConfig.getCoreParams();
  console.log(`   奖励/标记: ${hre.ethers.formatEther(core[0])} MEER`);
  console.log(`   审查费率: ${core[1] / 100}%`);
  console.log(`   准确率窗口: ${core[2] / 86400} 天`);
  
  // 5. 存款
  console.log('\n💰 向 IncentiveDistributor 存款 10 MEER...');
  await deployer.sendTransaction({
    to: await incentive.getAddress(),
    value: hre.ethers.parseEther('10')
  });
  console.log('   ✅ 存款完成');
  
  console.log('\n🎉 部署完成！');
  console.log('');
  console.log('========== 部署结果 ==========');
  console.log(`BronzeAmbassadorConfig: ${await bronzeConfig.getAddress()}`);
  console.log(`IncentiveDistributor:   ${await incentive.getAddress()}`);
  console.log(`SnapshotRecorder:       ${await snapshot.getAddress()}`);
}

main().catch(err => {
  console.error('❌ 部署失败:', err);
  process.exit(1);
});
