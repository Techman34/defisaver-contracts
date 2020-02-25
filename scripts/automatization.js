const Web3 = require('web3');
const Dec = require('decimal.js');

require('dotenv').config();

const DSProxy = require('../build/contracts/DSProxy.json');
const ProxyRegistryInterface = require('../build/contracts/ProxyRegistryInterface.json');
const DSSProxyActions = require('../build/contracts/DssProxyActions.json');
const GetCdps = require('../build/contracts/GetCdps.json');
const MCDSaverProxy = require('../build/contracts/MCDSaverProxy.json');

const Vat = require('../build/contracts/Vat.json');

const SubscriptionsProxy = require('../build/contracts/SubscriptionsProxy.json');
const Subscriptions = require('../build/contracts/Subscriptions.json');

const proxyRegistryAddr = '0x4678f0a6958e4D2Bc4F1BAF7Bc52E8F3564f3fE4';
const cdpManagerAddr = '0x5ef30b9986345249bc32d8928B7ee64DE9435E39';
const getCdpsAddr = '0x36a724bd100c39f0ea4d3a20f7097ee01a8ff573';
const mcdSaverProxyAddr = '0xee7cbe2044dee32b81331c432893a0f12dcabf5b';

const vatAddr = '0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B';

const subscriptionsProxyAddr = '0x7acBd2A64e35db26473b857754F9Dad85b6Be524';
const subscriptionsAddr = '0x83152CAA0d344a2Fd428769529e2d490A88f4393';

const ETH_ILK = '0x4554482d41000000000000000000000000000000000000000000000000000000';
const BAT_ILK = '0x4241542d41000000000000000000000000000000000000000000000000000000';

const zeroAddr = '0x0000000000000000000000000000000000000000';

const tokenJoinAddrData = {
    '1': {
        'ETH': '0x775787933e92b709f2a3c70aa87999696e74a9f8',
        'BAT': '0x2a4c485b1b8dfb46accfbecaf75b6188a59dbd0a',
        'GNT': '0xc667ac878fd8eb4412dcad07988fea80008b65ee',
        'OMG': '0x2ebb31f1160c7027987a03482ab0fec130e98251',
        'ZRX': '0x1f4150647b4aa5eb36287d06d757a5247700c521',
        'REP': '0xd40163ea845abbe53a12564395e33fe108f90cd3',
        'DGD': '0xd5f63712af0d62597ad6bf8d357f163bc699e18c',
    },
    '42': {
        'ETH': '0x775787933e92b709f2a3c70aa87999696e74a9f8',
        'BAT': '0x2a4c485b1b8dfb46accfbecaf75b6188a59dbd0a',
        'GNT': '0xc667ac878fd8eb4412dcad07988fea80008b65ee',
        'OMG': '0x2ebb31f1160c7027987a03482ab0fec130e98251',
        'ZRX': '0x1f4150647b4aa5eb36287d06d757a5247700c521',
        'REP': '0xd40163ea845abbe53a12564395e33fe108f90cd3',
        'DGD': '0xd5f63712af0d62597ad6bf8d357f163bc699e18c',
    }
};

const getTokenJoinAddr = (type) => {
    return tokenJoinAddrData['1'][type];
};

const initContracts = async () => {
    web3 = new Web3(new Web3.providers.HttpProvider(process.env.GANACHE));

    account = web3.eth.accounts.privateKeyToAccount('0x'+process.env.PRIV_KEY)
    web3.eth.accounts.wallet.add(account)

    registry = new web3.eth.Contract(ProxyRegistryInterface.abi, proxyRegistryAddr);
    getCdps = new web3.eth.Contract(GetCdps.abi, getCdpsAddr);
    mcdSaverProxy = new web3.eth.Contract(MCDSaverProxy.abi, mcdSaverProxyAddr);

    proxyAddr = '0xFe20b133167caaE3940D89927f772a68aDca8f36';
    proxy = new web3.eth.Contract(DSProxy.abi, proxyAddr);

    vat = new web3.eth.Contract(Vat.abi, vatAddr);
    subscriptionsProxy = new web3.eth.Contract(SubscriptionsProxy.abi, subscriptionsProxyAddr);
    subscriptions = new web3.eth.Contract(Subscriptions.abi, subscriptionsAddr);
};

function getAbiFunction(contract, functionName) {
    const abi = contract.abi;

    return abi.find(abi => abi.name === functionName);
}

(async () => {
    await initContracts();

    const cdps = await getCDPsForAddress(proxyAddr);
    const res = await getCdpInfo(cdps[1]);
    console.log(res);

    await boost(cdps[1].cdpId, '100', 'ETH');

    const res1 = await getCdpInfo(cdps[1]);
    console.log(res1);
})();

const getCDPsForAddress = async (proxyAddr) => {

    const cdps = await getCdps.methods.getCdpsAsc(cdpManagerAddr, proxyAddr).call();

    let usersCdps = [];

    cdps.ids.forEach((id, i) => {
        usersCdps.push({
            cdpId: id,
            urn: cdps.urns[i],
            ilk: cdps.ilks[i]
        });
    });

    return usersCdps;
}


const getCdpInfo = async (cdp) => {
    try {

        const ilkInfo = await getCollateralInfo(cdp.ilk, 0);
        const urn = await vat.methods.urns(cdp.ilk, cdp.urn).call();

        const collateral = Dec(urn.ink);
        const debt = Dec(urn.art);

        const debtWithFee = debt.times(ilkInfo.currentRate).div(1e27);

        const stabilityFee = debtWithFee.sub(debt);

        const ratio = collateral.times(ilkInfo.price).div(debtWithFee).times(100);

        const liquidationPrice = debt.times(ilkInfo.liquidationRatio).div(collateral);

        return {
            id: cdp.cdpId,
            type: cdp.ilk,
            collateral: collateral.toString(),
            debt: debt.toString(),
            debtWithFee: debtWithFee.toString(), // debt + stabilityFee
            stabilityFee: stabilityFee.div(1e18).toString(),
            ratio: ratio.toString(),
            liquidationPrice: liquidationPrice.toString()
        };
    } catch(err) {
        console.log(err);
    }
};

// either ilk or cdpId, if cdpId send bytes32(0) for ilk
const getCollateralInfo = async (ilk, cdpId) => {
    try {
        const ilkInfo = await subscriptions.methods.getIlkInfo(ilk, cdpId).call();

        let par = Dec(ilkInfo.par).div(1e27);
        const spot = Dec(ilkInfo.spot).div(1e27);
        const mat = Dec(ilkInfo.mat).div(1e27);

        const price = spot.times(par).times(mat);

        return {
            currentRate: ilkInfo.rate,
            price, // TODO: check if true
            minAmountForCdp: ilkInfo.dust,
            currAmountGlobal: ilkInfo.art, //total debt TODO: * rate
            maxAmountGlobal: ilkInfo.line,
            liquidationRatio: mat,
        }
    } catch(err) {
        console.log(err);
    }
};

const boost = async (cdpId, amount, type) => {
    try {
        const daiAmount = web3.utils.toWei(amount, 'ether');
        const uintData = ['2367', daiAmount, '0', '0', '0', '0'];

        const data = web3.eth.abi.encodeFunctionCall(getAbiFunction(MCDSaverProxy, 'boost'),
          [uintData, getTokenJoinAddr(type), '0x0000000000000000000000000000000000000000', '0x0']);

        const tx = await proxy.methods['execute(address,bytes)'](mcdSaverProxyAddr, data).send({
            from: account.address, gas: 3000000, common: {customChain: {chainId: 1337, networkId: 1}}});

        // console.log(tx);
    } catch(err) {
        console.log(err);
    }
};