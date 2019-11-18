const InstrumentManagerInterface = artifacts.require('./instrument/InstrumentManagerInterface.sol');
const InstrumentEscrowInterface = artifacts.require('./escrow/InstrumentEscrowInterface.sol');
const InstrumentRegistry = artifacts.require('./InstrumentRegistry.sol');
const SpotSwap = artifacts.require('./instrument/swap/SpotSwap.sol');
const ParametersUtil =artifacts.require('./lib/util/ParametersUtil.sol');
const TokenMock = artifacts.require('./mock/TokenMock.sol');

const runSpotSwapTestCases = async function(deployer, [owner, proxyAdmin, timerOracle, fsp, maker1, taker1, maker2, taker2, maker3, taker3]) {
    console.log('Running SpotSwap Test Cases...');
    const instrumentRegistry = await InstrumentRegistry.deployed();
    const spotSwap = await SpotSwap.deployed();
    const parametersUtil = await ParametersUtil.deployed();

    // Deploy ERC20 tokens
    const inputToken = await deployer.deploy(TokenMock);
    const outputToken = await deployer.deploy(TokenMock);

    const instrumentManagerAddress = await instrumentRegistry.lookupInstrumentManager(spotSwap.address, {from: fsp});
    console.log('Instrument manager address: ' + instrumentManagerAddress);
    const instrumentManager = await InstrumentManagerInterface.at(instrumentManagerAddress);
    const instrumentEscrowAddress = await instrumentManager.getInstrumentEscrowAddress({from: fsp});
    console.log('Instrument escrow address: ' + instrumentEscrowAddress);
    const instrumentEscrow = await InstrumentEscrowInterface.at(instrumentEscrowAddress);
    let spotSwapMakerParameters;

    /**************************** SpotSwap Issuance 1 *****************************************/
    console.log('Creating SpotSwap Issuance 1...');
    // Deposit input tokens to SpotSwap Instrument Escrow
    await inputToken.transfer(maker1, 2000000);
    await inputToken.approve(instrumentEscrowAddress, 2000000, {from: maker1});
    await instrumentEscrow.depositToken(inputToken.address, 2000000, {from: maker1});

    // Create spot swap issuance.
    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address,
        outputToken.address, 2000000, 40000, 20);
    await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker1});

    // Deposit output tokens to SpotSwap Instrument Escrow
    await outputToken.transfer(taker1, 40000);
    await outputToken.approve(instrumentEscrowAddress, 40000, {from: taker1});
    await instrumentEscrow.depositToken(outputToken.address, 40000, {from: taker1});

    // Engage spot swap issuance
    await instrumentManager.engageIssuance(1, '0x0', {from: taker1});

    /**************************** SpotSwap Issuance 2 *****************************************/
    console.log('Creating SpotSwap Issuance 2...');
    // Deposit input tokens to SpotSwap Instrument Escrow
    await inputToken.transfer(maker2, 43200000);
    await inputToken.approve(instrumentEscrowAddress, 43200000, {from: maker2});
    await instrumentEscrow.depositToken(inputToken.address, 43200000, {from: maker2});

    // Create spot swap issuance.
    spotSwapMakerParameters = await parametersUtil.getSpotSwapMakerParameters(inputToken.address,
        outputToken.address, 43200000, 3456, 20);
    await instrumentManager.createIssuance(spotSwapMakerParameters, {from: maker2});

    // Deposit output tokens to SpotSwap Instrument Escrow
    await outputToken.transfer(taker2, 3456);
    await outputToken.approve(instrumentEscrowAddress, 3456, {from: taker2});
    await instrumentEscrow.depositToken(outputToken.address, 3456, {from: taker2});

    // Engage spot swap issuance
    await instrumentManager.engageIssuance(2, '0x0', {from: taker2});
};

module.exports = function(deployer, network, accounts) {
deployer
    .then(() => runSpotSwapTestCases(deployer, accounts))
    .catch(error => {
      console.log(error);
      process.exit(1);
    });
};
