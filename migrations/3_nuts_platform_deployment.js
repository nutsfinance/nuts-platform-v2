// const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');
// const NUTSToken = artifacts.require('./token/NUTSToken.sol');
// const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');
// const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');
// const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
// const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
// const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');

// const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {

//     // Deploy Instrument Managers
//     let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);
//     let nutsToken = await NUTSToken.deployed();
//     // Deploy Price Oracle
//     let priceOracle = await deployer.deploy(PriceOracle);
//     // Deploy Escrow Factory
//     let escrowFactory = await deployer.deploy(EscrowFactory);
//     // Deploy Instrument Registry
//     let instrumentRegistry = await deployer.deploy(InstrumentRegistry, instrumentManagerFactory.address,
//         0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);
//     const parametersUtil = await deployer.deploy(ParametersUtil);
//     console.log("InstrumentManagerFactory address: " + instrumentManagerFactory.address);
//     console.log("PriceOracle address: " + priceOracle.address);
//     console.log("EscrowFactory address: " + escrowFactory.address);
//     console.log("InstrumentRegistry address: " + instrumentRegistry.address);
//     console.log("ParametersUtil address: " + parametersUtil.address);
// };

// module.exports = function(deployer, network, accounts) {
// deployer
//     .then(() => deployNutsPlatform(deployer, accounts))
//     .catch(error => {
//       console.log(error);
//       process.exit(1);
//     });
// };

const InstrumentManagerFactory = artifacts.require('./instrument/InstrumentManagerFactory.sol');	
const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');	
const NUTSToken = artifacts.require('./token/NUTSToken.sol');	
const PriceOracle = artifacts.require('./mock/PriceOracleMock.sol');	
const EscrowFactory = artifacts.require('./escrow/EscrowFactory.sol');	
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');	
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');	
const Saving = artifacts.require('./instrument/saving/Saving.sol');	
const Lending = artifacts.require('./instrument/lending/Lending.sol');	
const Borrowing = artifacts.require('./instrument/borrowing/Borrowing.sol');	
const SpotSwap = artifacts.require('./instrument/swap/SpotSwap.sol');	
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');	
const TokenMock = artifacts.require('./mock/TokenMock.sol');	

const deployNutsPlatform = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {	

    // Deploy Instrument Managers	
    let instrumentManagerFactory = await deployer.deploy(InstrumentManagerFactory);	

    // Deploy NUTS token	
    let nutsToken = await deployer.deploy(NUTSToken);	

    // Deploy Price Oracle	
    let priceOracle = await deployer.deploy(PriceOracle);	

    // Deploy Escrow Factory	
    let escrowFactory = await deployer.deploy(EscrowFactory);	

    // Deploy Instrument Registry	
    let instrumentRegistry = await deployer.deploy(InstrumentRegistry, instrumentManagerFactory.address,	
        0, 0, nutsToken.address, priceOracle.address, escrowFactory.address);	

    const parametersUtil = await deployer.deploy(ParametersUtil);	

    // // Deploy ERC20 tokens	
    // const lendingToken = await deployer.deploy(TokenMock);	
    // const collateralToken = await deployer.deploy(TokenMock);	
    // await priceOracle.setRate(lendingToken.address, collateralToken.address, 1, 100);	
    // await priceOracle.setRate(collateralToken.address, lendingToken.address, 100, 1);	

    /**	
     * Saving Instrument deployment	
     */	
    console.log('Deploying saving instrument.');	
    let saving = await deployer.deploy(Saving, {from: fsp});	
    let savingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);	
    // Activate Saving Instrument	
    await instrumentRegistry.activateInstrument(saving.address, savingInstrumentParameters, {from: fsp});	
    const savingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(1, {from: fsp});	
    console.log('Saving instrument manager address: ' + savingInstrumentManagerAddress);	
    const savingInstrumentManager = await InstrumentManagerInterface.at(savingInstrumentManagerAddress);	
    console.log('Get saving instrument');	
    const savingInstrumentEscrowAddress = await savingInstrumentManager.getInstrumentEscrowAddress({from: fsp});	
    console.log('Saving instrument escrow address: ' + savingInstrumentEscrowAddress);	

    /**	
     * Lending Instrument deployment	
     */	
    console.log('Deploying lending instrument.');	
    let lending = await deployer.deploy(Lending, {from: fsp});	
    let lendingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);	
    // Activate Lending Instrument	
    await instrumentRegistry.activateInstrument(lending.address, lendingInstrumentParameters, {from: fsp});	
    const lendingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(2, {from: fsp});	
    console.log('Lending instrument manager address: ' + lendingInstrumentManagerAddress);	
    const lendingInstrumentManager = await InstrumentManagerInterface.at(lendingInstrumentManagerAddress);	
    const lendingInstrumentEscrowAddress = await lendingInstrumentManager.getInstrumentEscrowAddress({from: fsp});	
    console.log('Lending instrument escrow address: ' + lendingInstrumentEscrowAddress);	

    /**	
     * Borrowing Instrument deployment	
     */	
    console.log('Deploying borrowing instrument.');	
    let borrowing = await deployer.deploy(Borrowing, {from: fsp});	
    let borrowingInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);	
    // Activate Borrowing Instrument	
    await instrumentRegistry.activateInstrument(borrowing.address, borrowingInstrumentParameters, {from: fsp});	
    const borrowingInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(3, {from: fsp});	
    console.log('Borrowing instrument manager address: ' + borrowingInstrumentManagerAddress);	
    const borrowingInstrumentManager = await InstrumentManagerInterface.at(borrowingInstrumentManagerAddress);	
    const borrowingInstrumentEscrowAddress = await borrowingInstrumentManager.getInstrumentEscrowAddress({from: fsp});	
    console.log('Borrowing instrument escrow address: ' + borrowingInstrumentEscrowAddress);	

    /**	
     * Spot Swap Instrument deployment	
     */	
    console.log('Deploying spot swap instrument.');	
    let swap = await deployer.deploy(SpotSwap, {from: fsp});	
    let swapInstrumentParameters = await parametersUtil.getInstrumentParameters(-1, -1, fsp, false, false);	
    // Activate Spot Swap Instrument	
    await instrumentRegistry.activateInstrument(swap.address, swapInstrumentParameters, {from: fsp});	
    const swapInstrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(4, {from: fsp});	
    console.log('Spot swap instrument manager address: ' + swapInstrumentManagerAddress);	
    const swapInstrumentManager = await InstrumentManagerInterface.at(swapInstrumentManagerAddress);	
    const swapInstrumentEscrowAddress = await swapInstrumentManager.getInstrumentEscrowAddress({from: fsp});	
    console.log('Spot swap instrument escrow address: ' + swapInstrumentEscrowAddress);	

    const mockUSD = '0x3EfC5E3c4CFFc638E9C506bb0F040EA0d8d3D094';
    const mockCNY = '0x2D5254e5905c6671b1804eac23Ba3F1C8773Ee46';
    const mockETH = '0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF';
    const mockUSDT = (await deployer.deploy(TokenMock, {from: fsp})).address;
    const mockUSDC = (await deployer.deploy(TokenMock, {from: fsp})).address;
    const mockDAI = (await deployer.deploy(TokenMock, {from: fsp})).address;
    const mockNUTS = nutsToken.address;

    // USD <--> CNY
    await priceOracle.setRate(mockUSD, mockCNY, 20, 3);
    await priceOracle.setRate(mockCNY, mockUSD, 3, 20);
    // USD <--> ETH
    await priceOracle.setRate(mockUSD, mockETH, 1, 200);
    await priceOracle.setRate(mockETH, mockUSD, 200, 1);
    // USD <--> USDT
    await priceOracle.setRate(mockUSD, mockUSDT, 1, 1);
    await priceOracle.setRate(mockUSDT, mockUSD, 1, 1);
    // USD <--> USDC
    await priceOracle.setRate(mockUSD, mockUSDC, 1, 1);
    await priceOracle.setRate(mockUSDC, mockUSD, 1, 1);
    // USD <--> DAI
    await priceOracle.setRate(mockUSD, mockDAI, 1, 1);
    await priceOracle.setRate(mockDAI, mockUSD, 1, 1);
    // USD <--> NUTS
    await priceOracle.setRate(mockUSD, mockNUTS, 4, 1);
    await priceOracle.setRate(mockNUTS, mockUSD, 1, 4);

    // CNY <--> ETH
    await priceOracle.setRate(mockCNY, mockETH, 3, 4000);
    await priceOracle.setRate(mockETH, mockCNY, 4000, 3);
    // CNY <--> USDT
    await priceOracle.setRate(mockCNY, mockUSDT, 3, 20);
    await priceOracle.setRate(mockUSDT, mockCNY, 20, 3);
    // CNY <--> USDC
    await priceOracle.setRate(mockCNY, mockUSDC, 3, 20);
    await priceOracle.setRate(mockUSDC, mockCNY, 20, 3);
    // CNY <--> DAI
    await priceOracle.setRate(mockCNY, mockDAI, 3, 20);
    await priceOracle.setRate(mockDAI, mockCNY, 20, 3);
    // CNY <--> NUTS
    await priceOracle.setRate(mockCNY, mockNUTS, 3, 5);
    await priceOracle.setRate(mockNUTS, mockCNY, 5, 3);

    // ETH <--> USDT
    await priceOracle.setRate(mockETH, mockUSDT, 200, 1);
    await priceOracle.setRate(mockUSDT, mockETH, 1, 200);
    // ETH <--> USDC
    await priceOracle.setRate(mockETH, mockUSDC, 200, 1);
    await priceOracle.setRate(mockUSDC, mockETH, 1, 200);
    // ETH <--> DAI
    await priceOracle.setRate(mockETH, mockDAI, 200, 1);
    await priceOracle.setRate(mockDAI, mockETH, 1, 200);
    // ETH <--> NUTS
    await priceOracle.setRate(mockETH, mockNUTS, 400, 1);
    await priceOracle.setRate(mockNUTS, mockETH, 1, 400);

    // USDT <--> USDC
    await priceOracle.setRate(mockUSDT, mockUSDC, 1, 1);
    await priceOracle.setRate(mockUSDC, mockUSDT, 1, 1);
    // USDT <--> DAI
    await priceOracle.setRate(mockUSDT, mockUSDC, 1, 1);
    await priceOracle.setRate(mockUSDC, mockUSDT, 1, 1);
    // USDT <--> NUTS
    await priceOracle.setRate(mockUSDT, mockUSDC, 5, 1);
    await priceOracle.setRate(mockUSDC, mockUSDT, 1, 5);

    // USDC <--> DAI
    await priceOracle.setRate(mockUSDC, mockDAI, 1, 1);
    await priceOracle.setRate(mockDAI, mockUSDC, 1, 1);
    // USDC <--> NUTS
    await priceOracle.setRate(mockUSDC, mockNUTS, 5, 1);
    await priceOracle.setRate(mockNUTS, mockUSDC, 1, 5);

    // DAI <--> NUTS
    await priceOracle.setRate(mockDAI, mockNUTS, 5, 1);
    await priceOracle.setRate(mockNUTS, mockDAI, 1, 5);

    const contractAddresses = {
        tokens: {
          USDT: mockUSDT,
          USDC: mockUSDC,
          DAI: mockDAI,
          NUTS: mockNUTS
        },
        platform: {
          lending: {
            instrumentManager: lendingInstrumentManagerAddress,
            instrumentEscrow: lendingInstrumentEscrowAddress
          },
          borrowing: {
            instrumentManager: borrowingInstrumentManagerAddress,
            instrumentEscrow: borrowingInstrumentEscrowAddress
          },
          saving: {
            instrumentManager: savingInstrumentManagerAddress,
            instrumentEscrow: savingInstrumentEscrowAddress
          },
          swap: {
            instrumentManager: swapInstrumentManagerAddress,
            instrumentEscrow: swapInstrumentEscrowAddress
          },
          parametersUtil: parametersUtil.address,
          priceOracle: priceOracle.address
        }
    };
    console.log(contractAddresses)
};	

module.exports = function(deployer, network, accounts) {	
deployer	
    .then(() => deployNutsPlatform(deployer, accounts))	
    .catch(error => {	
    console.log(error);	
    process.exit(1);	
    });	
};