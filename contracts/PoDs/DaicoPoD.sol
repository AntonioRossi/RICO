pragma solidity ^0.4.18;
import "../PoD.sol";
import "../EIP20StandardToken.sol";

/// @title DaicoPoD - DaicoPoD contract
/// @author - Yusaku Senga - <senga@dri.network>
/// license let's see in LICENSE

contract DaicoPoD is PoD {

  uint256 public tap;
  uint256 public lastWithdrawn;

  mapping(address => uint256) lockedVotePowers;  //Deposit based Stake counter.

  uint256 public voterCount;
  uint256 public reundPrice;
  bool public refundable;

  EIP20StandardToken public token;

  uint256 tokenMultiplier;

  struct Proposal {
    uint256 openVoteTime;
    uint256 closeVoteTime;
    uint256 totalVoted;
    uint256 newTap;
    bool isDestruct;
    mapping(bool => uint256) voted;
    mapping(address => bool) isVote;
  }

  Proposal[] proposals;
    

  event Voted(address user, bool flag);

  function DaicoPoD() public {
    name = "DaicoPoD strategy token with dao";
    version = "0.9.3";
    tap = 0;
    voterCount = 0;
    refundable = false;
  }

  function init(
    address _wallet, 
    uint8 _tokenDecimals, 
    address _token
  ) 
  public onlyOwner() returns (bool) 
  {
    require(status == Status.PoDDeployed);
    require(_wallet != 0x0);
    wallet = _wallet;
    startTime = block.timestamp;
    token = EIP20StandardToken(_token);
    tokenMultiplier = 10 ** uint256(_tokenDecimals);
    require(token.balanceOf(this) == 0);
    status = Status.PoDStarted;
    return true;
  }


  function depositToken(uint256 _amount) public returns (bool) {

    require(token.transferFrom(msg.sender, this, _amount));

    lockedVotePowers[msg.sender] = lockedVotePowers[msg.sender].add(_amount);

    voterCount = voterCount.add(1);

    return true;
  }

  function withdrawalToken() public returns (bool) {
    
    var proposal = proposals[proposals.length-1];

    require(!proposal.isVote[msg.sender]);

    token.transfer(msg.sender, lockedVotePowers[msg.sender]);

    voterCount = voterCount.sub(1);

    lockedVotePowers[msg.sender] = 0;
  }

  function vote(bool _flag) public returns (bool) {

    var proposal = proposals[proposals.length-1];

    require(block.timestamp >= proposal.openVoteTime);
    require(block.timestamp < proposal.closeVoteTime);

    require(!proposal.isVote[msg.sender]);

    require(lockedVotePowers[msg.sender] >= tokenMultiplier.mul(5000));

    proposal.isVote[msg.sender] = true;
    proposal.voted[_flag] = proposal.voted[_flag].add(1);
    proposal.totalVoted = proposal.totalVoted.add(1);

    Voted(msg.sender, _flag);
  }


  function aggregate(uint256 nextOpenTime, uint256 nextCloseTime, uint256 _newTap, bool _isDestruct) public returns (bool) {

    var proposal = proposals[proposals.length-1];

    require(block.timestamp >= proposal.closeVoteTime);
    require(block.timestamp >= nextOpenTime);
    require(nextCloseTime >= nextOpenTime.add(7 days));

    require(!refundable);

    uint votedUsers = proposal.voted[true].add(proposal.voted[false]);

    //require(votedUsers >= 20);

    uint absent = voterCount.sub(votedUsers);

    if (proposal.voted[true] > proposal.voted[false].add(absent.div(6))) {
      if (proposal.isDestruct) {
        refundable = true;
        tap = 0;
      } else {
        modifyTap(proposal.newTap);
      }
    }

    require(tap < _newTap);

    Proposal memory newProposal = Proposal({
      openVoteTime: nextOpenTime,
      closeVoteTime: nextCloseTime,
      newTap: _newTap,
      isDestruct: _isDestruct,
      totalVoted: 0
    });

    proposals.push(newProposal);

    return true;
  }

  function withdraw() public {

    wallet.transfer((block.timestamp - lastWithdrawn) * tap);

    lastWithdrawn = block.timestamp;
  }

  function decreaseTap(uint256 _newTap) public onlyOwner() returns (bool) {

    require(tap > _newTap);

    modifyTap(_newTap);
  }

  function refund() public returns (bool) {

    require(refundable);

    uint refundAmount = this.balance * lockedVotePowers[msg.sender] / token.balanceOf(this);

    msg.sender.transfer(refundAmount);

    lockedVotePowers[msg.sender] = 0;
    
    return true;
  }


  function modifyTap(uint256 newTap) internal returns (bool) {
    withdraw();
    tap = newTap;
  }

  function processDonate(address _user) internal returns (bool) {
    require(_user != 0x0);
    return true;
  }

  function finalize() public onlyOwner() {

    require(status == Status.PoDStarted);

    endTime = now;

    status = Status.PoDEnded;

    Ended(endTime);
  }

  function getBalanceOfToken(address _user) public constant returns (uint256) {
    return 0;
  }
}
