pragma solidity ^0.4.15;

import 'zeppelin-solidity/contracts/math/SafeMath.sol';
import './McFlyToken.sol';
import './Haltable.sol';
import './MultiOwners.sol';


contract McFlyCrowdsale is MultiOwners, Haltable {
    using SafeMath for uint256;

    // min wei per tx for TLP 1.1
    uint256 public minimalWeiTLP1 = 1e17; // 0.1 ETH
    uint256 public priceTLP1 = 1e14; // 0.0001 ETH

    // min wei per tx for TLP 1.2
    uint256 public minimalWeiTLP2 = 2e17; // 0.2 ETH
    uint256 public priceTLP2 = 2e14; // 0.0002 ETH

    // Total ETH received during WAVES, TLP1.1 and TLP1.2
    uint256 public totalETH;

    // Token
    McFlyToken public token;

    // Withdraw wallet
    address public wallet;

    // start and end timestamp for TLP 1.1, endTimeTLP1 calculate from startTimeTLP1
    uint256 public startTimeTLP1;
    uint256 public endTimeTLP1;
    uint256 daysTLP1 = 12 days;

    // start and end timestamp for TLP 1.2, endTimeTLP2 calculate from startTimeTLP2
    uint256 public startTimeTLP2;
    uint256 public endTimeTLP2;
    uint256 daysTLP2 = 24 days;

    // Percents
    uint256 fundPercents = 15;
    uint256 teamPercents = 10;
    uint256 reservedPercents = 10;
    uint256 bountyOnlinePercents = 2;
    uint256 bountyOfflinePercents = 3;
    uint256 advisoryPercents = 5;
    
    // Cap
    // maximum possible tokens for minting
    uint256 public hardCapInTokens = 1800e24; // 1,800,000,000 MFL

    // maximum possible tokens for sell 
    uint256 public mintCapInTokens = hardCapInTokens.mul(70).div(100); // 1,260,000,000 MFL

    // maximum possible tokens for fund minting
    uint256 public fundTokens = hardCapInTokens.mul(fundPercents).div(100); // 270,000,000 MFL
    uint256 public fundTotalSupply;
    address public fundMintingAgent;

    // Rewards
    // WAVES
    // maximum possible tokens to convert from WAVES
    uint256 public wavesTokens = 100e24; // 100,000,000 MFL
    address public wavesAgent;

    // Team 10%
    uint256 teamVestingPeriodInSeconds = 31 days;
    uint256 teamVestingPeriodsCount = 12;
    uint256 public teamTokens;
    uint256 public teamTotalSupply;
    address public teamWallet;

    // Bounty 5% (2% + 3%)
    // Bounty online 2%
    uint256 public bountyOnlineTokens;
    address public bountyOnlineWallet;

    // Bounty offline 3%
    uint256 public bountyOfflineTokens;
    address public bountyOfflineWallet;

    // Advisory 5%
    uint256 public advisoryTokens;
    address public advisoryWallet;

    // Reserved for future 10%
    uint256 public reservedTokens;
    address public reservedWallet;


    event TokenPurchase(address indexed beneficiary, uint256 value, uint256 amount);
    event TransferOddEther(address indexed beneficiary, uint256 value);
    event FundMinting(address indexed beneficiary, uint256 value);
    event TeamVesting(address indexed beneficiary, uint256 period, uint256 value);
    event SetFundMintingAgent(address new_agent);
    event SetStartTimeTLP2(uint256 new_startTimeTLP2);


    modifier validPurchase() {
        bool nonZeroPurchase = msg.value != 0;
        
        require(withinPeriod() && nonZeroPurchase);

        _;        
    }

    function McFlyCrowdsale(
        uint256 _startTimeTLP1,
        uint256 _startTimeTLP2,
        address _wallet,
        address _wavesAgent,
        address _fundMintingAgent,
        address _teamWallet,
        address _bountyOnlineWallet,
        address _bountyOfflineWallet,
        address _advisoryWallet,
        address _reservedWallet
    ) {
        require(_startTimeTLP1 >= block.timestamp);
        require(_startTimeTLP2 > _startTimeTLP1);
        require(_wallet != 0x0);
        require(_wavesAgent != 0x0);
        require(_fundMintingAgent != 0x0);
        require(_teamWallet != 0x0);
        require(_bountyOnlineWallet != 0x0);
        require(_bountyOfflineWallet != 0x0);
        require(_advisoryWallet != 0x0);
        require(_reservedWallet != 0x0);

        token = new McFlyToken();

        startTimeTLP1 = _startTimeTLP1; 
        endTimeTLP1 = startTimeTLP1.add(daysTLP1);

        require(endTimeTLP1 < _startTimeTLP2);

        startTimeTLP2 = _startTimeTLP2; 
        endTimeTLP2 = startTimeTLP2.add(daysTLP2);

        wavesAgent = _wavesAgent;
        fundMintingAgent = _fundMintingAgent;

        wallet = _wallet;
        teamWallet = _teamWallet;
        bountyOnlineWallet = _bountyOnlineWallet;
        bountyOfflineWallet = _bountyOfflineWallet;
        advisoryWallet = _advisoryWallet;
        reservedWallet = _reservedWallet;

        totalETH = wavesTokens.mul(priceTLP1.mul(65).div(100)).div(1e18); // 6500 for 100,000,000 MFL from WAVES
        token.mint(wavesAgent, wavesTokens);
        token.allowTransfer(wavesAgent);
    }

    function withinPeriod() constant public returns (bool) {
        bool withinPeriodTLP1 = (now >= startTimeTLP1 && now <= endTimeTLP1);
        bool withinPeriodTLP2 = (now >= startTimeTLP2 && now <= endTimeTLP2);
        return withinPeriodTLP1 || withinPeriodTLP2;
    }

    // @return false if crowdsale event was ended
    function running() constant public returns (bool) {
        return withinPeriod() && !token.mintingFinished();
    }

    // @return current stage name
    function stageName() constant public returns (string) {
        bool beforePeriodTLP1 = (now < startTimeTLP1);
        bool withinPeriodTLP1 = (now >= startTimeTLP1 && now <= endTimeTLP1);
        bool betweenPeriodTLP1andTLP2 = (now >= endTimeTLP1 && now <= startTimeTLP2);
        bool withinPeriodTLP2 = (now >= startTimeTLP2 && now <= endTimeTLP2);

        if(beforePeriodTLP1) {
            return 'Not started';
        }

        if(withinPeriodTLP1) {
            return 'TLP1.1';
        } 

        if(betweenPeriodTLP1andTLP2) {
            return 'Between TLP1.1 and TLP1.2';
        }

        if(withinPeriodTLP2) {
            return 'TLP1.2';
        }

        return 'Finished';
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable {
        return buyTokens(msg.sender);
    }

    /*
     * @dev change agent for waves minting
     * @praram agent - new agent address
     */
    function setFundMintingAgent(address agent) onlyOwner {
        fundMintingAgent = agent;
        SetFundMintingAgent(agent);
    }

    /*
     * @dev set TLP1.2 start date
     * @param _at — new start date
     */
    function setStartTimeTLP2(uint256 _at) onlyOwner {
        require(block.timestamp < startTimeTLP2); // forbid change time when TLP1.2 is active
        require(block.timestamp < _at); // should be great than current block timestamp
        require(endTimeTLP1 < _at); // should be great than end TLP1.1

        startTimeTLP2 = _at;
        endTimeTLP2 = startTimeTLP2.add(daysTLP2);
        SetStartTimeTLP2(_at);
    }

    /*
     * @dev set TLP1.1 start date
     * @param _at - new start date
     */
    function setStartTimeTLP1(uint256 _at) onlyOwner {
        require(block.timestamp < startTimeTLP1); // forbid change time when TLP1.1 is active
        require(block.timestamp < _at); // should be great than current block timestamp

        startTimeTLP1 = _at;
        endTimeTLP1 = startTimeTLP1.add(daysTLP1);
        SetStartTimeTLP1(_at);
    }

    /*
     * @dev Large Token Holder minting 
     * @param to - mint to address
     * @param amount - how much mint
     */
    function fundMinting(address to, uint256 amount) stopInEmergency {
        require(msg.sender == fundMintingAgent || isOwner());
        require(block.timestamp <= startTimeTLP2);
        require(fundTotalSupply + amount <= fundTokens);
        require(token.totalSupply() + amount <= mintCapInTokens);

        fundTotalSupply = fundTotalSupply.add(amount);
        FundMinting(to, amount);
        token.mint(to, amount);
    }

    /*
     * @dev calculate amount
     * @param  _value - ether to be converted to tokens
     * @param  at - current time
     * @param  _totalSupply - total supplied tokens
     * @return tokens amount that we should send to our dear investor
     * @return odd ethers amount, which contract should send back
     */
    function calcAmountAt(
        uint256 amount,
        uint256 at,
        uint256 _totalSupply
    ) public constant returns (uint256, uint256) {
        uint256 estimate;
        uint256 discount;
        uint256 price;

        if(at >= startTimeTLP1 && at <= endTimeTLP1) {
            /*
                35% 0.0650 | 1 ETH -> 1 / (100-35) * 100 / 0.1 * 1000 = 15384.61538461538 MFL
                30% 0.0700 | 1 ETH -> 1 / (100-30) * 100 / 0.1 * 1000 = 14285.714287 MFL
                15% 0.0850 | 1 ETH -> 1 / (100-15) * 100 / 0.1 * 1000 = 11764.705882352941 MFL
                 0% 0.1000 | 1 ETH -> 1 / (100-0) * 100  / 0.1 * 1000 = 10000 MFL
            */
            require(amount >= minimalWeiTLP1);

            price = priceTLP1;

            if(at < startTimeTLP1 + 3 days) {
                discount = 65; //  100-35 = 0.065 ETH per 1000 MFL

            } else if(at < startTimeTLP1 + 6 days) {
                discount = 70; //  100-30 = 0.07 ETH per 1000 MFL

            } else if(at < startTimeTLP1 + 9 days) {
                discount = 85; //  100-15 = 0.085 ETH per 1000 MFL

            } else if(at < startTimeTLP1 + 12 days) {
                discount = 100; // 100 = 0.1 ETH per 1000 MFL

            } else {
                revert();
            }

        } else if(at >= startTimeTLP2 && at <= endTimeTLP2) {
            /*
                 -40% 0.12 | 1 ETH -> 1 / (100-40) * 100 / 0.2 * 1000 = 8333.3333333333 MFL
                 -30% 0.14 | 1 ETH -> 1 / (100-30) * 100 / 0.2 * 1000 = 7142.8571428571 MFL
                 -20% 0.16 | 1 ETH -> 1 / (100-20) * 100 / 0.2 * 1000 = 6250 MFL
                 -10% 0.18 | 1 ETH -> 1 / (100-10) * 100 / 0.2 * 1000 = 5555.5555555556 MFL
                   0% 0.20 | 1 ETH -> 1 / (100-0) * 100 / 0.2 * 1000  = 5000 MFL
                  10% 0.22 | 1 ETH -> 1 / (100+10) * 100 / 0.2 * 1000 = 4545.4545454545 MFL
                  20% 0.24 | 1 ETH -> 1 / (100+20) * 100 / 0.2 * 1000 = 4166.6666666667 MFL
                  30% 0.26 | 1 ETH -> 1 / (100+30) * 100 / 0.2 * 1000 = 3846.1538461538 MFL
            */
            require(amount >= minimalWeiTLP2);

            price = priceTLP2;

            if(at < startTimeTLP2 + 3 days) {
                discount = 60; // 100-40 = 0.12 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 6 days) {
                discount = 70; // 100-30 = 0.14 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 9 days) {
                discount = 80; // 100-20 = 0.16 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 12 days) {
                discount = 90; // 100-10 = 0.18 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 15 days) {
                discount = 100; // 100 = 0.2 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 18 days) {
                discount = 110; // 100+10 = 0.22 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 21 days) {
                discount = 120; // 100+20 = 0.24 ETH per 1000 MFL

            } else if(at < startTimeTLP2 + 24 days) {
                discount = 130; // 100+30 = 0.26 ETH per 1000 MFL

            } else {
                revert();
            }
        } else {
            revert();
        }

        price = price.mul(discount).div(100);
        estimate = _totalSupply.add(amount.mul(1e18).div(price));

        if(estimate > mintCapInTokens) {
            return (
                mintCapInTokens.sub(_totalSupply),
                estimate.sub(mintCapInTokens).mul(price).div(1e18)
            );
        }
        return (estimate.sub(_totalSupply), 0);
    }

    /*
     * @dev sell token and send to contributor address
     * @param contributor address
     */
    function buyTokens(address contributor) payable stopInEmergency validPurchase public {
        uint256 amount;
        uint256 odd_ethers;
        uint256 ethers;
        
        (amount, odd_ethers) = calcAmountAt(msg.value, block.timestamp, token.totalSupply());
  
        require(contributor != 0x0) ;
        require(amount + token.totalSupply() <= mintCapInTokens);

        ethers = (msg.value - odd_ethers);

        token.mint(contributor, amount); // fail if minting is finished
        TokenPurchase(contributor, ethers, amount);
        totalETH += ethers;

        if(odd_ethers > 0) {
            require(odd_ethers < msg.value);
            TransferOddEther(contributor, odd_ethers);
            contributor.transfer(odd_ethers);
        }


        wallet.transfer(ethers);
    }

    function teamWithdraw() public {
        // check
        require(token.mintingFinished());
        require(msg.sender == teamWallet || isOwner());

        uint256 currentPeriod = (block.timestamp).sub(endTimeTLP2).div(teamVestingPeriodInSeconds);
        if(currentPeriod > teamVestingPeriodsCount) {
            currentPeriod = teamVestingPeriodsCount;
        }
        uint256 tokenAvailable = teamTokens.mul(currentPeriod).div(teamVestingPeriodsCount).sub(teamTotalSupply);

        require(teamTotalSupply + tokenAvailable <= teamTokens);

        teamTotalSupply = teamTotalSupply.add(tokenAvailable);

        TeamVesting(teamWallet, currentPeriod, tokenAvailable);
        token.transfer(teamWallet, tokenAvailable);

    }

    function finishCrowdsale() onlyOwner public {
        require(now > endTimeTLP2 || mintCapInTokens == token.totalSupply());
        require(!token.mintingFinished());

        uint256 _totalSupply = token.totalSupply();

        // rewards
        teamTokens = _totalSupply.mul(teamPercents).div(70); // 180,000,000 MFL
        token.mint(this, teamTokens); // mint to contract address

        reservedTokens = _totalSupply.mul(reservedPercents).div(70); // 180,000,000 MFL
        token.mint(reservedWallet, reservedTokens);

        advisoryTokens = _totalSupply.mul(advisoryPercents).div(70); // 90,000,000 MFL
        token.mint(advisoryWallet, advisoryTokens);

        bountyOfflineTokens = _totalSupply.mul(bountyOfflinePercents).div(70); // 54,000,000 MFL
        token.mint(bountyOfflineWallet, bountyOfflineTokens);

        bountyOnlineTokens = _totalSupply.mul(bountyOnlinePercents).div(70); // 36,000,000 MFL
        token.mint(bountyOnlineWallet, bountyOnlineTokens);

        token.finishMinting();
   }

}