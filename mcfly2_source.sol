pragma solidity ^0.4.19;

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;
  address public candidate;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to _request_ transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function requestOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    candidate = newOwner;
  }

  /**
   * @dev Allows the _NEW_ candidate to complete transfer control of the contract to him.
   */
  function confirmOwnership() public {
    require(candidate == msg.sender);
    OwnershipTransferred(owner, candidate);
    owner = candidate;
  }

}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    uint256 _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue) public
    returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue) public
    returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

contract MintableToken is StandardToken, Ownable {
  event Mint(address indexed to, uint256 amount);
  event MintFinished();

  bool public mintingFinished = false;


  modifier canMint() {
    require(!mintingFinished);
    _;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) onlyOwner canMint public returns (bool) {
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(0x0, _to, _amount);
    return true;
  }

  /**
   * @dev Function to stop minting new tokens.
   * @return True if the operation was successful.
   */
  function finishMinting() onlyOwner public returns (bool) {
    mintingFinished = true;
    MintFinished();
    return true;
  }
}

contract McFlyToken is MintableToken {

    string public constant name = 'McFlyToken';
    string public constant symbol = 'McFly';
    uint8 public constant decimals = 18;

    mapping(address=>bool) whitelist;

    event Burn(address indexed from, uint256 value);
    event AllowTransfer(address from);

    modifier canTransfer() {
        require(mintingFinished || whitelist[msg.sender]);
        _;        
    }

    function allowTransfer(address from) onlyOwner public {
        AllowTransfer(from);
        whitelist[from] = true;
    }

    function transferFrom(address from, address to, uint256 value) canTransfer public returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function transfer(address to, uint256 value) canTransfer public returns (bool) {
        return super.transfer(to, value);
    }

    function burn(address from) onlyOwner public returns (bool) {
        Transfer(from, 0x0, balances[from]);
        Burn(from, balances[from]);

        balances[0x0] += balances[from];
        balances[from] = 0;
    }
}

contract MultiOwners {

    event AccessGrant(address indexed owner);
    event AccessRevoke(address indexed owner);
    
    mapping(address => bool) owners;
    address public publisher;


    function MultiOwners() public {
        owners[msg.sender] = true;
        publisher = msg.sender;
    }

    modifier onlyOwner() { 
        require(owners[msg.sender] == true);
        _; 
    }

    function isOwner() constant public returns (bool) {
        return owners[msg.sender] ? true : false;
    }

    function checkOwner(address maybe_owner) constant public returns (bool) {
        return owners[maybe_owner] ? true : false;
    }


    function grant(address _owner) onlyOwner public {
        owners[_owner] = true;
        AccessGrant(_owner);
    }

    function revoke(address _owner) onlyOwner public {
        require(_owner != publisher);
        require(msg.sender != _owner);

        owners[_owner] = false;
        AccessRevoke(_owner);
    }
}

contract Haltable is MultiOwners {
    bool public halted;

    modifier stopInEmergency {
        require(!halted);
        _;
    }

    modifier onlyInEmergency {
        require(halted);
        _;
    }

    // called by the owner on emergency, triggers stopped state
    function halt() external onlyOwner {
        halted = true;
    }

    // called by the owner on end of emergency, returns to normal state
    function unhalt() external onlyOwner onlyInEmergency {
        halted = false;
    }

}

contract McFlyCrowdsale is MultiOwners, Haltable {
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

    // tokens saled within TLP2
    uint256 public saledTokensTLP2;

    // tokens saled before this contract (MFL tokens)
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

    // array of investors (addr, amount of eth) for window Nx
    struct Investor1 { uint256 eth_in; }
    mapping (address => Investor1) investors1;
    address[] public investorAccts1;
    
    struct Investor2 { uint256 eth_in; }
    mapping (address => Investor2) investors2;
    address[] public investorAccts2;
    
    struct Investor3 { uint256 eth_in; }
    mapping (address => Investor3) investors3;
    address[] public investorAccts3;
    
    struct Investor4 { uint256 eth_in; }
    mapping (address => Investor4) investors4;
    address[] public investorAccts4;
    
    struct Investor5 { uint256 eth_in; }
    mapping (address => Investor5) investors5;
    address[] public investorAccts5;

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
    function McFlyCrowdsale(
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
        saledTokensTLP2 = saledTokensTLP2.add(_preMcFlyTokens);

        token.mint(wavesAgent, wavesTokens); // 100,000,000 MFL
        token.allowTransfer(wavesAgent);
        saledTokensTLP2 = saledTokensTLP2.add(wavesTokens);

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

    // @return false if crowdsale event was ended
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

    // get info about investors at window 1-5
    function getInvestors(uint256 __at) view public returns(address[]) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return investorAccts1;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return investorAccts2;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return investorAccts3;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return investorAccts4;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return investorAccts5;
            }
    }
    
    // get info about investors at window 1-5
    function getInvestor(uint256 __at, address _address) view public returns (uint256) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return (investors1[_address].eth_in);
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return (investors2[_address].eth_in);
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return (investors3[_address].eth_in);
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return (investors4[_address].eth_in);
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return (investors5[_address].eth_in);
            }
    }
    
    // count investors at window 1-5
    function countInvestors(uint256 __at) view public returns (uint) {
            if(__at >= startTimeTLP3 && __at <= endTimeTLP3) {
                return investorAccts1.length;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                return investorAccts2.length;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                return investorAccts3.length;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                return investorAccts4.length;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                return investorAccts5.length;
            }
    }

    /*
     * @dev fallback for processing ether
     */
    function() payable public {
        return buyTokens(msg.sender);
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
        require(block.timestamp <= endTimeTLP2);
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
     * @return tokens amount that we should send to our dear investor
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
    function buyTokens(address contributor) payable stopInEmergency validPurchase public {
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
            saledTokensTLP2 = saledTokensTLP2.add(amount);

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
                var investor1 = investors1[contributor];
                investor1.eth_in = msg.value;
                investorAccts1.push(contributor) -1;
                window1 = window1.add(msg.value);
                window1_cnt++;
            }
            
            if(__at >= startTimeTLP4 && __at <= endTimeTLP4) {
                var investor2 = investors2[contributor];
                investor2.eth_in = msg.value;
                investorAccts2.push(contributor) -1;
                window2 = window2.add(msg.value);
                window2_cnt++;
            }
            
            if(__at >= startTimeTLP5 && __at <= endTimeTLP5) {
                var investor3 = investors3[contributor];
                investor3.eth_in = msg.value;
                investorAccts3.push(contributor) -1;
                window3 = window3.add(msg.value);
                window3_cnt++;
            }
            
            if(__at >= startTimeTLP6 && __at <= endTimeTLP6) {
                var investor4 = investors4[contributor];
                investor4.eth_in = msg.value;
                investorAccts4.push(contributor) -1;
                window4 = window4.add(msg.value);
                window4_cnt++;
            }
            
            if(__at >= startTimeTLP7 && __at <= endTimeTLP7) {
                var investor5 = investors5[contributor];
                investor5.eth_in = msg.value;
                investorAccts5.push(contributor) -1;
                window5 = window5.add(msg.value);                
                window5_cnt++;
            }

            TokenPurchaseInWindow(contributor, msg.value);
            
            wallet.transfer(msg.value);
        }
    }

    // close sale window N1 and transfer tokens to investors1 accts.
    function closeWindow1() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window1isClosed);
        require(window1 > 0);
        require(countInvestors(block.timestamp) > 0);

        _McFlyperETH = window1CapInTokens.div(window1); // max McFly in window

        for (uint i = 0; i < countInvestors(block.timestamp); i++) {
            token.transfer(investorAccts1[i], (_McFlyperETH.mul(investors1[investorAccts1[i]].eth_in)));
        }  
        window1isClosed = true;
    }

    function closeWindow2() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window2isClosed);
        require(window2 > 0);
        require(countInvestors(block.timestamp) > 0);

        _McFlyperETH = window2CapInTokens.div(window2); // max McFly in window

        for (uint i = 0; i < countInvestors(block.timestamp); i++) {
            token.transfer(investorAccts2[i], (_McFlyperETH.mul(investors2[investorAccts2[i]].eth_in)));
        }        
        window2isClosed = true;
    }

    function closeWindow3() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window3isClosed);
        require(window3 > 0);
        require(countInvestors(block.timestamp) > 0);

        _McFlyperETH = window3CapInTokens.div(window3); // max McFly in window

        for (uint i = 0; i < countInvestors(block.timestamp); i++) {
            token.transfer(investorAccts3[i], (_McFlyperETH.mul(investors3[investorAccts3[i]].eth_in)));
        }      
        window3isClosed = true;
    }

    function closeWindow4() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window4isClosed);
        require(window4 > 0);
        require(countInvestors(block.timestamp) > 0);

        _McFlyperETH = window4CapInTokens.div(window4); // max McFly in window

        for (uint i = 0; i < countInvestors(block.timestamp); i++) {
            token.transfer(investorAccts4[i], (_McFlyperETH.mul(investors4[investorAccts4[i]].eth_in)));
        }        
        window4isClosed = true;
    }

    function closeWindow5() onlyOwner stopInEmergency public {
        uint256 _McFlyperETH;
        require(!window5isClosed);
        require(window5 > 0);
        require(countInvestors(block.timestamp) > 0);

        _McFlyperETH = window5CapInTokens.div(window5); // max McFly in window

        for (uint i = 0; i < countInvestors(block.timestamp); i++) {
            token.transfer(investorAccts5[i], (_McFlyperETH.mul(investors5[investorAccts5[i]].eth_in)));
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


    function finishCrowdsale() onlyOwner public {
        require(now > endTimeTLP2 || hardCapInTokens == token.totalSupply());
        require(!token.mintingFinished());

        windowsCapInTokens = saledTokensTLP2.add(fundTotalSupply);
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
