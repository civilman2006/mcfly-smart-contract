pragma solidity ^0.4.19;

import './SafeMath.sol';
import './McFlyToken.sol';
import './Haltable.sol';
import './MultiOwners.sol';


contract McFlyCrowd is MultiOwners, Haltable {
    using SafeMath for uint256;

    // Total ETH received during WAVES, TLP1.2 & window[1-5]
    uint256 public counter_in; // tlp2
    uint256 public window1;
    uint256 public window2;
    uint256 public window3;
    uint256 public window4;
    uint256 public window5;
    
    // total count of transactions in window Nx
    uint256 public window1_cnt;
    uint256 public window2_cnt;
    uint256 public window3_cnt;
    uint256 public window4_cnt;
    uint256 public window5_cnt;
    
    // is true -> window Nx is closed
    bool public window1isClosed;
    bool public window2isClosed;
    bool public window3isClosed;
    bool public window4isClosed;
    bool public window5isClosed;

    // minimum ETH to partisipate in window 1-5
    uint256 public minETHin = 1e18; // 1 ETH

    // Token
    McFlyToken public token;

    // Withdraw wallet
    address public wallet;

    // start and end timestamp for TLP 1.2, endTimeTLP2 calculate from startTimeTLP2
    uint256 public startTimeTLP2;
    uint256 public endTimeTLP2;
    uint256 daysTLP2 = 56 days;

    uint256 daysBetweenTLP = 60 days;
    uint256 daysTLP3_7 = 12 days; // 12 days for 3,4,5,6,7 windows;
    // start and end timestamp for TLP 1.3, endTimeTLP3 calculate from startTimeTLP3
    uint256 public startTimeTLP3;
    uint256 public endTimeTLP3;
    // start and end timestamp for TLP 1.4, endTimeTLP4 calculate from startTimeTLP4
    uint256 public startTimeTLP4;
    uint256 public endTimeTLP4;
    // start and end timestamp for TLP 1.5, endTimeTLP5 calculate from startTimeTLP5
    uint256 public startTimeTLP5;
    uint256 public endTimeTLP5;
    // start and end timestamp for TLP 1.6, endTimeTLP6 calculate from startTimeTLP6
    uint256 public startTimeTLP6;
    uint256 public endTimeTLP6;
    // start and end timestamp for TLP 1.7, endTimeTLP7 calculate from startTimeTLP7
    uint256 public startTimeTLP7;
    uint256 public endTimeTLP7;

    // Percents
    uint256 fundPercents = 15;

    // Cap
    // maximum possible tokens for minting
    uint256 public hardCapInTokens = 1800e24; // 1,800,000,000 MFL

    // maximum possible tokens for sell 
    uint256 public mintCapInTokens = hardCapInTokens.mul(70).div(100); // 1,260,000,000 MFL

    // tokens crowd within TLP2
    uint256 public crowdTokensTLP2;

    // tokens crowd before this contract (MFL tokens)
    uint256 public preMcFlyTotalSupply;

    // maximum possible tokens for fund minting
    uint256 public fundTokens = hardCapInTokens.mul(fundPercents).div(100); // 270,000,000 MFL
    uint256 public fundTotalSupply;
    address public fundMintingAgent;

    // maximum possible tokens for sell within period 3 - 7. (mintCapInTokens-selled tokens)
    uint256 public windowsCapInTokens;
    uint256 public window1CapInTokens; //window1
    uint256 public window2CapInTokens;
    uint256 public window3CapInTokens;
    uint256 public window4CapInTokens;
    uint256 public window5CapInTokens;

    // array of ppls (addr, amount of eth) for window Nx
    struct Ppl1 { uint256 eth_in; }
    mapping (address => Ppl1) ppls1;
    address[] public pplAccts1;
    
    struct Ppl2 { uint256 eth_in; }
    mapping (address => Ppl2) ppls2;
    address[] public pplAccts2;
    
    struct Ppl3 { uint256 eth_in; }
    mapping (address => Ppl3) ppls3;
    address[] public pplAccts3;
    
    struct Ppl4 { uint256 eth_in; }
    mapping (address => Ppl4) ppls4;
    address[] public pplAccts4;
    
    struct Ppl5 { uint256 eth_in; }
    mapping (address => Ppl5) ppls5;
    address[] public pplAccts5;

    // Rewards
    // WAVES
    // maximum possible tokens to convert from WAVES
    uint256 public wavesTokens = 100e24; // 100,000,000 MFL
    address public wavesAgent;

    // Vesting for team, advisory, reserve.
    uint256 VestingPeriodInSeconds = 30 days; // 24 month
    uint256 VestingPeriodsCount = 24;

    // Team 10%
    uint256 _teamTokens;
    uint256 public teamTotalSupply;
    address public teamWallet;

    // Bounty 5% (2% + 3%)
    // Bounty online 2%
    uint256 _bountyOnlineTokens;
    address public bountyOnlineWallet;

    // Bounty offline 3%
    uint256 _bountyOfflineTokens;
    address public bountyOfflineWallet;

    // Advisory 5%
    uint256 _advisoryTokens;
    uint256 public advisoryTotalSupply;
    address public advisoryWallet;

    // Reserved for future 9%
    uint256 _reservedTokens;
    uint256 public reservedTotalSupply;
    address public reservedWallet;

    // AirDrop 1%
    uint256 _airdropTokens;
    address public airdropWallet;

    // PreMcFly wallet (MFL)
    uint256 _preMcFlyTokens;
    address public preMcFlyWallet;

    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event TokenPurchaseInWindow(address indexed beneficiary, uint256 value);
    event TransferOddEther(address indexed beneficiary, uint256 value);
    event FundMinting(address indexed beneficiary, uint256 value);
    event TeamVesting(address indexed beneficiary, uint256 period, uint256 value);
    event AdvisoryVesting(address indexed beneficiary, uint256 period, uint256 value);
    event ReservedVesting(address indexed beneficiary, uint256 period, uint256 value);
    event SetFundMintingAgent(address new_agent);
    event SetStartTimeTLP2(uint256 new_startTimeTLP2);


    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;
        
//        require(withinPeriod() && nonZeroPurchase);
        require(nonZeroPurchase);

        _;        
    }

    // constructor run once!
    function McFlyCrowd(
        uint256 _startTimeTLP2,
        uint256 _preMcFlyTotalSupply,
        address _wallet,
        address _wavesAgent,
        address _fundMintingAgent,
        address _teamWallet,
        address _bountyOnlineWallet,
        address _bountyOfflineWallet,
        address _advisoryWallet,
        address _reservedWallet,
        address _airdropWallet,
        address _preMcFlyWallet
    ) public {
        require(_startTimeTLP2 >= block.timestamp);
        require(_preMcFlyTotalSupply > 0);
        require(_wallet != 0x0);
        require(_wavesAgent != 0x0);
        require(_fundMintingAgent != 0x0);
        require(_teamWallet != 0x0);
        require(_bountyOnlineWallet != 0x0);
        require(_bountyOfflineWallet != 0x0);
        require(_advisoryWallet != 0x0);
        require(_reservedWallet != 0x0);
        require(_airdropWallet != 0x0);
        require(_preMcFlyWallet != 0x0);

        token = new McFlyToken();

        wallet = _wallet;

        setStartEndTimeTLP(_startTimeTLP2); 

        wavesAgent = _wavesAgent;
        fundMintingAgent = _fundMintingAgent;

        teamWallet = _teamWallet;
        bountyOnlineWallet = _bountyOnlineWallet;
        bountyOfflineWallet = _bountyOfflineWallet;
        advisoryWallet = _advisoryWallet;
        reservedWallet = _reservedWallet;
        airdropWallet = _airdropWallet;
        preMcFlyWallet = _preMcFlyWallet;

        // Mint all tokens and than control it by vesting
        _preMcFlyTokens = _preMcFlyTotalSupply; // McFly for thansfer to old MFL owners
        token.mint(preMcFlyWallet, _preMcFlyTokens);
        token.allowTransfer(preMcFlyWallet);
        crowdTokensTLP2 = crowdTokensTLP2.add(_preMcFlyTokens);

        token.mint(wavesAgent, wavesTokens); // 100,000,000 MFL
        token.allowTransfer(wavesAgent);
        crowdTokensTLP2 = crowdTokensTLP2.add(wavesTokens);

        // rewards !!!!
        _teamTokens = 180e24; // 180,000,000 MFL
        token.mint(this, _teamTokens); // mint to contract address

        _bountyOnlineTokens = 36e24; // 36,000,000 MFL
        token.mint(bountyOnlineWallet, _bountyOnlineTokens);
        token.allowTransfer(bountyOnlineWallet);

        _bountyOfflineTokens = 54e24; // 54,000,000 MFL
        token.mint(bountyOfflineWallet, _bountyOfflineTokens);
        token.allowTransfer(bountyOfflineWallet);

        _advisoryTokens = 90e24; // 90,000,000 MFL
        token.mint(this, _advisoryTokens);

        _reservedTokens = 162e24; // 162,000,000 MFL
        token.mint(this, _reservedTokens);

        _airdropTokens = 18e24; // 18,000,000 MFL
        token.mint(airdropWallet, _airdropTokens);
        token.allowTransfer(airdropWallet);
    }

    function withinPeriod() constant public returns (bool) {
        bool withinPeriodTLP2 = (now >= startTimeTLP2 && now <= endTimeTLP2);
        return withinPeriodTLP2;
    }

    // @return false if crowd event was ended
    function running() constant public returns (bool) {
        return withinPeriod() && !token.mintingFinished();
    }

    function teamTokens() constant public returns (uint256) {
            return _teamTokens;
    }

    function bountyOnlineTokens() constant public returns (uint256) {
            return _bountyOnlineTokens;
    }

    function bountyOfflineTokens() constant public returns (uint256) {
            return _bountyOfflineTokens;
    }

    function advisoryTokens() constant public returns (uint256) {
            return _advisoryTokens;
    }

    function reservedTokens() constant public returns (uint256) {
            return _reservedTokens;
    }

    function airdropTokens() constant public returns (uint256) {
            return _airdropTokens;
    }

    function preMcFlyTokens() constant public returns (uint256) {
            return _preMcFlyTokens;
    }

    // @return current stage name
    function stageName() constant public returns (string) {
        bool beforePeriodTLP2 = (now < startTimeTLP2);
        
        bool withinPeriodTLP2 = (now >= startTimeTLP2 && now <= endTimeTLP2);
        bool betweenPeriodTLP2andTLP3 = (now >= endTimeTLP2 && now <= startTimeTLP3);
        
        bool withinPeriodTLP3 = (now >= startTimeTLP3 && now <= endTimeTLP3);
        
        bool betweenPeriodTLP3andTLP4 = (now >= endTimeTLP3 && now <= startTimeTLP4);
        bool withinPeriodTLP4 = (now >= startTimeTLP4 && now <= endTimeTLP4);
        
        bool betweenPeriodTLP4andTLP5 = (now >= endTimeTLP4 && now <= startTimeTLP5);
        bool withinPeriodTLP5 = (now >= startTimeTLP5 && now <= endTimeTLP5);
        
        bool betweenPeriodTLP5andTLP6 = (now >= endTimeTLP5 && now <= startTimeTLP6);
        bool withinPeriodTLP6 = (now >= startTimeTLP6 && now <= endTimeTLP6);
        
        bool betweenPeriodTLP6andTLP7 = (now >= endTimeTLP6 && now <= startTimeTLP7);
        bool withinPeriodTLP7 = (now >= startTimeTLP7 && now <= endTimeTLP7);
    
        if(beforePeriodTLP2) {
            return 'Not started';
        }
        if(withinPeriodTLP2) {
            return 'TLP1.2';
        } 
        if(betweenPeriodTLP2andTLP3) {
            return 'Between TLP1.2 and TLP1.3';
        }
        if(withinPeriodTLP3) {
            return 'TLP1.3';
        }
        if(betweenPeriodTLP3andTLP4) {
            return 'Between TLP1.3 and TLP1.4';
        }
        if(withinPeriodTLP4) {
            return 'TLP1.4';
        }
        if(betweenPeriodTLP4andTLP5) {
            return 'Between TLP1.4 and TLP1.5';
        }
        if(withinPeriodTLP5) {
            return 'TLP1.5';
        }
        if(betweenPeriodTLP5andTLP6) {
            return 'Between TLP1.5 and TLP1.6';
        }
        if(withinPeriodTLP6) {
            return 'TLP1.6';
        }
        if(betweenPeriodTLP6andTLP7) {
            return 'Between TLP1.6 and TLP1.7';
        }
        if(withinPeriodTLP7) {
            return 'TLP1.7';
        }

        return 'Finished';
    }

    // get info about ppls at window 1-5
    function getPpls(uint256 __at) view public returns(address[]) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return pplAccts1;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return pplAccts2;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return pplAccts3;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return pplAccts4;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return pplAccts5;
            }
    }
    
    // get info about ppls at window 1-5
    function getPpl(uint256 __at, address _address) view public returns (uint256) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return (ppls1[_address].eth_in);
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return (ppls2[_address].eth_in);
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return (ppls3[_address].eth_in);
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return (ppls4[_address].eth_in);
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return (ppls5[_address].eth_in);
            }
    }
    
    // count ppls at window 1-5
    function countPpls(uint256 __at) view public returns (uint) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return pplAccts1.length;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return pplAccts2.length;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return pplAccts3.length;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return pplAccts4.length;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return pplAccts5.length;
            }
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable public {
        return getTokens(msg.sender);
    }

    /*
     * @dev change agent for waves minting
     * @praram agent - new agent address
     */
    function setFundMintingAgent(address agent) onlyOwner public {
        fundMintingAgent = agent;
        SetFundMintingAgent(agent);
    }

    /*
     * @dev set TLP1.X (3-7) start & end dates
     * @param _at - new or old start date
     */
    function setStartEndTimeTLP(uint256 _at) onlyOwner public {
        SetStartTimeTLP2(_at);
        
        // sets start and end timestamp for TLP 1.3, endTimeTLP3 calculate from startTimeTLP3
        startTimeTLP3 = endTimeTLP2.add(daysBetweenTLP);
        endTimeTLP3 = startTimeTLP3.add(daysTLP3_7);
        startTimeTLP4 = endTimeTLP3.add(daysBetweenTLP);
        endTimeTLP4 = startTimeTLP4.add(daysTLP3_7);
        startTimeTLP5 = endTimeTLP4.add(daysBetweenTLP);
        endTimeTLP5 = startTimeTLP5.add(daysTLP3_7);
        startTimeTLP6 = endTimeTLP5.add(daysBetweenTLP);
        endTimeTLP6 = startTimeTLP6.add(daysTLP3_7);
        startTimeTLP7 = endTimeTLP6.add(daysBetweenTLP);
        endTimeTLP7 = startTimeTLP7.add(daysTLP3_7);
    }

    /*
     * @dev set TLP1.2 start date
     * @param _at - new start date
     */
    function setStartTimeTLP2(uint256 _at) onlyOwner public {
        require(block.timestamp < startTimeTLP2); // forbid change time when TLP1.2 is active
        require(block.timestamp < _at); // should be great than current block timestamp

        startTimeTLP2 = _at;
        endTimeTLP2 = startTimeTLP2.add(daysTLP2);
        SetStartTimeTLP2(_at);
    }
    
    /*
     * @dev Large Token Holder minting 
     * @param to - mint to address
     * @param amount - how much mint
     */
    function fundMinting(address to, uint256 amount) stopInEmergency public {
        require(msg.sender == fundMintingAgent || isOwner());
        require(block.timestamp < startTimeTLP2);
        require(fundTotalSupply + amount <= fundTokens);
        require(token.totalSupply() + amount <= hardCapInTokens);

        fundTotalSupply = fundTotalSupply.add(amount);
        FundMinting(to, amount);
        token.mint(to, amount);
    }

    /*
     * @dev calculate amount
     * @param  _value - ether to be converted to tokens
     * @param  at - current time
     * @param  _totalSupply - total supplied tokens
     * @return tokens amount that we should send to our dear ppl
     * @return odd ethers amount, which contract should send back
     */
    function calcAmountAt(
        uint256 amount,
        uint256 at,
        uint256 _totalSupply
    ) public constant returns (uint256, uint256) {
        uint256 estimate;
        uint256 price;

        if(at >= startTimeTLP2 && at <= endTimeTLP2) {
            // require(amount >= minimalWeiTLP2); // checks min ETH income for 1 transaction

            if(at < startTimeTLP2 + 7 days) {
                price = 12e13; // (1 McFly=0.00012)     0.00012   RECHECK !!!!!!!!!!!!!!!!!!! 5ETH*1e18/12e13=41666/5=8333,33McFly
            } else if(at < startTimeTLP2 + 14 days) {
                price = 14e13; // (1 McFly=0.00014)
            } else if(at < startTimeTLP2 + 21 days) {
                price = 16e13; // (1 McFly=0.00016)
            } else if(at < startTimeTLP2 + 28 days) {
                price = 18e13; // (1 McFly=0.00018)
            } else if(at < startTimeTLP2 + 35 days) {
                price = 20e13; // (1 McFly=0.00020)
            } else if(at < startTimeTLP2 + 42 days) {
                price = 22e13; // (1 McFly=0.00022)
            } else if(at < startTimeTLP2 + 49 days) {
                price = 24e13; // (1 McFly=0.00024)
            } else if(at < startTimeTLP2 + 56 days) {
                price = 26e13; // (1 McFly=0.00026)
            } else {
                revert();
            }
        } else {
            revert();
        }

        estimate = _totalSupply.add(amount.mul(1e18).div(price));

        if(estimate > hardCapInTokens) {
            return (
                hardCapInTokens.sub(_totalSupply),
                estimate.sub(hardCapInTokens).mul(price).div(1e18)
            );
        }
        return (estimate.sub(_totalSupply), 0);
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function getTokens(address contributor) payable stopInEmergency validPurchase public {
        uint256 amount;
        uint256 odd_ethers;
        uint256 ethers;
        uint256 __at;
        
        __at = block.timestamp;
        
        if(__at >= startTimeTLP2 && __at <= endTimeTLP2) {
        
            (amount, odd_ethers) = calcAmountAt(msg.value, __at, token.totalSupply());  // recheck!!!
  
            require(contributor != 0x0) ;
            require(amount + token.totalSupply() <= hardCapInTokens);

            ethers = (msg.value - odd_ethers);

            token.mint(contributor, amount); // fail if minting is finished
            TokenPurchase(contributor, ethers, amount);
            counter_in += ethers;
            crowdTokensTLP2 = crowdTokensTLP2.add(amount);

            if(odd_ethers > 0) {
                require(odd_ethers < msg.value);
                TransferOddEther(contributor, odd_ethers);
                contributor.transfer(odd_ethers);
            }

            wallet.transfer(ethers);
        } else
        {
            require(msg.value >= minETHin); // checks min ETH income

            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                var ppl1 = ppls1[contributor];
                ppl1.eth_in = msg.value;
                pplAccts1.push(contributor) -1;
                window1 = window1.add(msg.value);
                window1_cnt++;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                var ppl2 = ppls2[contributor];
                ppl2.eth_in = msg.value;
                pplAccts2.push(contributor) -1;
                window2 = window2.add(msg.value);
                window2_cnt++;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                var ppl3 = ppls3[contributor];
                ppl3.eth_in = msg.value;
                pplAccts3.push(contributor) -1;
                window3 = window3.add(msg.value);
                window3_cnt++;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                var ppl4 = ppls4[contributor];
                ppl4.eth_in = msg.value;
                pplAccts4.push(contributor) -1;
                window4 = window4.add(msg.value);
                window4_cnt++;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                var ppl5 = ppls5[contributor];
                ppl5.eth_in = msg.value;
                pplAccts5.push(contributor) -1;
                window5 = window5.add(msg.value);                
                window5_cnt++;
            }

            TokenPurchaseInWindow(contributor, msg.value);
            
            wallet.transfer(msg.value);
        }
    }

    // close window N1 and transfer tokens to ppls1 accts.
    function closeWindow1() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window1isClosed);
        require(window1 > 0);
        require(countPpls(block.timestamp) > 0);

        _McFlyperETH = window1CapInTokens.div(window1); // max McFly in window

        for (uint i = 0; i < countPpls(block.timestamp); i++) {
            token.transfer(pplAccts1[i], (_McFlyperETH.mul(ppls1[pplAccts1[i]].eth_in)));
        }  
        window1isClosed = true;
    }

    function closeWindow2() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window2isClosed);
        require(window2 > 0);
        require(countPpls(block.timestamp) > 0);

        _McFlyperETH = window2CapInTokens.div(window2); // max McFly in window

        for (uint i = 0; i < countPpls(block.timestamp); i++) {
            token.transfer(pplAccts2[i], (_McFlyperETH.mul(ppls2[pplAccts2[i]].eth_in)));
        }        
        window2isClosed = true;
    }

    function closeWindow3() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window3isClosed);
        require(window3 > 0);
        require(countPpls(block.timestamp) > 0);

        _McFlyperETH = window3CapInTokens.div(window3); // max McFly in window

        for (uint i = 0; i < countPpls(block.timestamp); i++) {
            token.transfer(pplAccts3[i], (_McFlyperETH.mul(ppls3[pplAccts3[i]].eth_in)));
        }      
        window3isClosed = true;
    }

    function closeWindow4() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window4isClosed);
        require(window4 > 0);
        require(countPpls(block.timestamp) > 0);

        _McFlyperETH = window4CapInTokens.div(window4); // max McFly in window

        for (uint i = 0; i < countPpls(block.timestamp); i++) {
            token.transfer(pplAccts4[i], (_McFlyperETH.mul(ppls4[pplAccts4[i]].eth_in)));
        }        
        window4isClosed = true;
    }

    function closeWindow5() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window5isClosed);
        require(window5 > 0);
        require(countPpls(block.timestamp) > 0);

        _McFlyperETH = window5CapInTokens.div(window5); // max McFly in window

        for (uint i = 0; i < countPpls(block.timestamp); i++) {
            token.transfer(pplAccts5[i], (_McFlyperETH.mul(ppls5[pplAccts5[i]].eth_in)));
        }      
        window5isClosed = true;
    
    }

    function teamWithdraw() public {
        require(token.mintingFinished());
        require(msg.sender == teamWallet || isOwner());

        uint256 currentPeriod = (block.timestamp).sub(endTimeTLP2).div(VestingPeriodInSeconds);
        if(currentPeriod > VestingPeriodsCount) {
            currentPeriod = VestingPeriodsCount;
        }
        uint256 tokenAvailable = _teamTokens.mul(currentPeriod).div(VestingPeriodsCount).sub(teamTotalSupply);  // RECHECK!!!!!

        require(teamTotalSupply + tokenAvailable <= _teamTokens);

        teamTotalSupply = teamTotalSupply.add(tokenAvailable);

        TeamVesting(teamWallet, currentPeriod, tokenAvailable);
        token.transfer(teamWallet, tokenAvailable);

    }

    function advisoryWithdraw() public {
        require(token.mintingFinished());
        require(msg.sender == advisoryWallet || isOwner());

        uint256 currentPeriod = (block.timestamp).sub(endTimeTLP2).div(VestingPeriodInSeconds);
        if(currentPeriod > VestingPeriodsCount) {
            currentPeriod = VestingPeriodsCount;
        }
        uint256 tokenAvailable = _advisoryTokens.mul(currentPeriod).div(VestingPeriodsCount).sub(advisoryTotalSupply);  // RECHECK!!!!!

        require(advisoryTotalSupply + tokenAvailable <= _advisoryTokens);

        advisoryTotalSupply = advisoryTotalSupply.add(tokenAvailable);

        AdvisoryVesting(advisoryWallet, currentPeriod, tokenAvailable);
        token.transfer(advisoryWallet, tokenAvailable);

    }

    function reservedWithdraw() public {
        require(token.mintingFinished());
        require(msg.sender == reservedWallet || isOwner());

        uint256 currentPeriod = (block.timestamp).sub(endTimeTLP2).div(VestingPeriodInSeconds);
        if(currentPeriod > VestingPeriodsCount) {
            currentPeriod = VestingPeriodsCount;
        }
        uint256 tokenAvailable = _reservedTokens.mul(currentPeriod).div(VestingPeriodsCount).sub(reservedTotalSupply);  // RECHECK!!!!!

        require(reservedTotalSupply + tokenAvailable <= _reservedTokens);

        reservedTotalSupply = reservedTotalSupply.add(tokenAvailable);

        ReservedVesting(reservedWallet, currentPeriod, tokenAvailable);
        token.transfer(reservedWallet, tokenAvailable);

    }


    function finishCrowd() onlyOwner public {
        require(now > endTimeTLP2 || hardCapInTokens == token.totalSupply());
        require(!token.mintingFinished());

        windowsCapInTokens = crowdTokensTLP2.add(fundTotalSupply);
        window1CapInTokens = windowsCapInTokens.div(5);
        window2CapInTokens = windowsCapInTokens.div(5);
        window3CapInTokens = windowsCapInTokens.div(5);
        window4CapInTokens = windowsCapInTokens.div(5);
        window5CapInTokens = windowsCapInTokens.div(5);
        token.mint(this, window1CapInTokens); // mint to contract address
        token.mint(this, window2CapInTokens); // mint to contract address
        token.mint(this, window3CapInTokens); // mint to contract address
        token.mint(this, window4CapInTokens); // mint to contract address
        token.mint(this, window5CapInTokens); // mint to contract address

        // shoud be MAX tokens minted!!! 1,800,000,000

        token.finishMinting();
    
   }

}
