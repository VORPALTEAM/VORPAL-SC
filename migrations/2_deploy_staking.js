const MasterChef = artifacts.require("MasterChef"); 
const SmartChef = artifacts.require("SmartChefV2"); 
const BSW = artifacts.require("BSWToken"); 

module.exports = async function (deployer, network, accounts) {
    const currentBlock = await web3.eth.getBlock('latest');
    console.log(currentBlock.latest); 
    // await deployer.deploy(BSW); 
    // const bsw = await BSW.deployed();
    // const bswperblock = 100; 
    // const startblock = 0; 
    // const stakingpercent = 2; 
    // const onepercent = 1;  
    // await deployer.deploy(MasterChef, 
    //     bsw.address,
    //     accounts[1], 
    //     accounts[1], 
    //     accounts[1],
    //     bswperblock,  
    //     startblock, 
    //     stakingpercent,
    //     onepercent, 
    //     onepercent,
    //     onepercent); 
    // await deployer.deploy(SmartChef, 
    //     bsw.address, 
    //     "0xa4cd3cbb12709115d400b11b29abfd6072d465be", 
    //     200,
    //     0,
    //     300
    // );
    // const masterchef = await MasterChef.deployed(); 
    // const smartchef = await SmartChef.deployed(); 
    // await bsw.addMinter(masterchef.address); 
    // await bsw.addMinter(smartchef.address); 
    // await masterchef.add('1000', "0x34B826A48b3e97287d31E1d79bEA48fCbF49426b", true);
}