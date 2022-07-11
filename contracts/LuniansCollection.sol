//      :-+++-:.                                       .:-+++-:     
//   .-+==:--+*+=.                                   .=**+:::--=-.  
//   +*-:-=++++++*=                                 =**+++++=-:.++  
//  -+=-=+++==+++++*=                             =**++++==+++=:-=- 
//  ++--++=-----=+++*#-                         -#*+++=-::--=++-.=+ 
//  ++--++---::::-=++**#:      :::::::::      :#**++=-:::::--++-.=+ 
// ++=--++---:::::-++****: :+++=========+++: :****++-::::::--++-::=+
// :+=--++=--::::-=++*###+++----:::::::::::-=+*##*++=-:::::-=++-:-+:
//  ++--+++=--::-=++##**#+----:::::::::....::+#++##++=-:::-=+++-.=+ 
//  ++--+++++===++*#*++**=----:::::::::::..::-+*+++#*++===+++++-.=+ 
//   ++--=++++++*#*+++++#+=++-:::::--::::::-+*++++++*#*++++++=-:==  
//   .=+-:++++*#**++++++***=---:--++=---****++++++++++*#*++++:.==.  
//    =*-::--*#**++++++++*********+*****+++++++++++++++*#*--::.+=   
//  :+=--++::#**+++++******+++++++++++++++++******++++++*#::++:.-=: 
//  -===-  =#***++*%%+++**#%#*+++++++++++*#%#**+++%%*++++*#=  -===- 
//          #***##+..  .-====#***+++++***#====-.  ..+#****#         
//          #***#+   :--=+=--==*+++++++*==--=+=--:   +#++*#         
//          #**+**=  =-::--::-=+++++++++=-::--::-=  =**++*#         
//          #***+**- :-:....:-+++++*+++++-:....:-: -**+++*#         
//           ***+++#*..--====+++++***+++++====--..*#++++**          
//           =***+=--::::::-=++++++*++++++=-::::::--=++**=          
//            =**+::-:::...:-+++++***+++++-:...:::-::=**=           
//             .+*+==::::-==++++*+-:-+*++++==-::::==+*+.            
//               .+#**++++++++#%-:::::-%#++++++++++*+.              
//                 .+**+++++++++*=:::=*++++++++++*+.                
//                   .++***+++++++++++++++++***++.                  
//                      .:=*****************=:.                     
// .____     ____ __________  .___   _____    _______    _________
// |    |   |    |   \      \ |   | /  _  \   \      \  /   _____/
// |    |   |    |   /   |   \|   |/  /_\  \  /   |   \ \_____  \ 
// |    |___|    |  /    |    \   /    |    \/    |    \/        \
// |________\______/\____|____/___\____|____/\____|____/_________/
//
// https://www.mycutepixel-nft.com/Lunians
// Twitter: @mycutepixel_nft

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


abstract contract ContextMixin {
    function msgSender() internal view returns (address payable sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = payable(msg.sender);
        }
        return sender;
    }
}


contract LuniansCollection is ERC1155, Ownable, ERC2981, VRFConsumerBase, ContextMixin {

    // Base variables
    string public name;
    string public symbol; 
    bool private paused = true;
    string public contractURI;
    uint256 public mintedLunians = 0;
    uint256 public maxLunians;
    uint8 public constant maxSingularLunians = 9; // Hmmmm..... Have you found something?
    uint256 private maxNebulaSeedpods;
    uint256 private seedpodCount = 0;
    uint256 private openSeedpodCount = 0;
    string private seedpodURI;
    string private hatchedSeedpodURI;
    string private lunianURI;
    string[maxSingularLunians] private singularLunianURI;
    bool private remains = false;
    
    // ChainLink oracle for randomness
    bytes32 private keyHash;
    uint256 private fee;
    uint256[] public availableLunianIds;
    uint256[] public availableNebulaIds;
    bool public rollState;
    mapping(bytes32 => address) private rollers;
    mapping(address => uint256) private mintingAmount;
    mapping(address => uint256) private mintingSeedpodId;
    event DiceRolled(bytes32 indexed requestId, address indexed roller);
    event DiceLanded(bytes32 indexed requestId, uint256 indexed result);
    event LunianMinted(address indexed lunianOwner, uint256 indexed lunianId);

    // Freezing tokens metadata and authorized second smart contract to add future features (fusing & dynamic NFTs)
    bool public frozenMetadata = false;
    event PermanentURI(string _value, uint256 indexed _id); // OpenSea event to notify about freezing
    address public authorized;
    bool public frozenAuthorized = false;
    event PermanentAuthorizedContract(address _value);

    constructor(string memory _name, string memory _symbol, string memory _lunianURI, 
    string memory _seedpodURI, string memory _contractURI, address _vrfCoordinator, address _link, 
    bytes32 _keyHash, uint256 _fee, uint256[] memory _nebulaIds, uint256[] memory _lunianIds) 
    VRFConsumerBase(_vrfCoordinator, _link) ERC1155(_lunianURI) {
        name = _name;
        symbol = _symbol;
        lunianURI = _lunianURI;
        seedpodURI = _seedpodURI;
        contractURI = _contractURI;
        keyHash = _keyHash;
        fee = _fee;
        super._setDefaultRoyalty(owner(), 600);
        availableNebulaIds = _nebulaIds;
        availableLunianIds = _lunianIds;
        maxNebulaSeedpods = availableNebulaIds.length;
        maxLunians = maxNebulaSeedpods + availableLunianIds.length;
    }


    /* 
    ** Private/Internal Functions 
    */

    // Used instead of msg.sender so that transactions are not sent by the original token owner, 
    // but by the marketplace (at least, opensea).
    function _msgSender() internal override view returns (address sender) {
        return ContextMixin.msgSender();
    }

    function rollDice(address roller) private returns (bytes32 requestId) {
        // checking LINK balance
        require(linkBalance() >= fee, "Not enough LINK to pay fee");

        // requesting randomness
        requestId = requestRandomness(keyHash, fee);
        // storing requestId and roller address
        rollers[requestId] = roller;
        // emitting event to signal rolling of dice
        rollState = true;
        emit DiceRolled(requestId, roller);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        // emitting event to signal that dice landed
        emit DiceLanded(requestId, randomness);
        // Reset dice throw state for the user so they can mint again
        rollState = false;
        // mint
        randomNMints(requestId, randomness, mintingAmount[rollers[requestId]], mintingSeedpodId[rollers[requestId]]);
    }

    function randomNMints(bytes32 requestId, uint256 randomness, uint256 n, uint256 seedpodId) private {
        require(n <= balanceOf(rollers[requestId], seedpodId), 
                "Not enough seedpods owned to mint the specified number of lunians");
        _burn(rollers[requestId], seedpodId, n); // burn seedpods
        uint256 value;
        uint256[] memory selectedIds = new uint[](n);
        uint256[] memory ammounts = new uint[](n);
        for (uint256 i = 0; i < n; i++) {
            if (isNebulaSeedpod(seedpodId)) {
                // transform the result to a number between 0 and the remaining Nebula Seedpods
                value = uint256(keccak256(abi.encode(randomness, i))) % availableNebulaIds.length;
                selectedIds[i] = availableNebulaIds[value];
                availableNebulaIds[value] = availableNebulaIds[availableNebulaIds.length-1];
                availableNebulaIds.pop();
            } else {
                // transform the result to a number between 0 and the remaining Lunian Seedpods
                value = uint256(keccak256(abi.encode(randomness, i))) % availableLunianIds.length;
                selectedIds[i] = availableLunianIds[value];
                availableLunianIds[value] = availableLunianIds[availableLunianIds.length-1];
                availableLunianIds.pop();
            }
            ammounts[i] = 1;
            emit PermanentURI(
                string(abi.encodePacked(
                        lunianURI,
                        Strings.toString(selectedIds[i]),
                        ".json"
                )), selectedIds[i]);
            emit LunianMinted(rollers[requestId], selectedIds[i]);
        }
        _mintBatch(rollers[requestId], selectedIds, ammounts, ""); // mint lunians
        mintedLunians += n;
    }

    // Tokens with id maxLunians + 3 and maxLunians + 4 are hatched nebula and lunian seedpods, respectively
    function mintOpenSeedpod(uint256 _amount, uint256 _seedpodId) private {
        require(openSeedpodCount < seedpodCount, "Can not mint more hatched seedpods (limit reached)");
        require(openSeedpodCount + _amount <= seedpodCount, "Can not mint so many hatched seedpods");
        
        if (_seedpodId == maxLunians + 1) { // nebula seedpod
            _mint(msg.sender, maxLunians + 3, _amount, "");
            emit PermanentURI(
                string(abi.encodePacked(
                        seedpodURI,
                        "HatchedNebulaSeedpod",
                        ".json"
                )), maxLunians + 3);
        } else { // lunian seedpod
            _mint(msg.sender, maxLunians + 4, _amount, "");
            emit PermanentURI(
                string(abi.encodePacked(
                        seedpodURI,
                        "HatchedLunianSeedpod",
                        ".json"
                )), maxLunians + 4);
        }

        openSeedpodCount += _amount;
    }

    function isSeedpod(uint256 _tokenId) private view returns(bool) {
        if (_tokenId > maxLunians && _tokenId <= maxLunians + 4) {
            return true;
        } else {
            return false;
        }
    }

    function isNebulaSeedpod(uint256 _tokenId) private view returns(bool) {
        if (_tokenId == maxLunians + 1) {
            return true;
        } else {
            return false;
        }
    }


    /* 
    ** Public/External Write Functions 
    */

    function setURISeedpod(string memory _newuri) external onlyOwner {
        require(!frozenMetadata, "Metadata is frozen forever!");
        seedpodURI = _newuri;
    }

    function setURIHatchedSeedpod(string memory _newuri) external onlyOwner {
        require(!frozenMetadata, "Metadata is frozen forever!");
        hatchedSeedpodURI = _newuri;
    }

    function setURILunian(string memory _newuri) external {
        require(!frozenMetadata || msg.sender == authorized, 
                "Metadata is frozen forever except for dynamic NFTs support from authorized contract");
        require(msg.sender == owner() || msg.sender == authorized, "Not authorized");
        lunianURI = _newuri;
    }

    function setURISingularLunian(uint256 id, string memory _newuri) external {
        require(!frozenMetadata || msg.sender == authorized, 
                "Metadata is frozen forever except for dynamic NFTs support from authorized contract");
        require(msg.sender == owner() || msg.sender == authorized, "Not authorized");
        require(id >= 0 && id < maxSingularLunians, "Id out of bounds");
        singularLunianURI[id] = _newuri;
    }

    function freezeMetadata() external onlyOwner {
        // READ IF YOU ARE A COLLECTOR! This (together with the IPFS hosting) is what makes sure your NFTs'
        // metadata is frozen FOREVER. Exception: See next (needed to support dynamic NFTs).
        frozenMetadata = true;
    }

    function freezeAuthorizedContract() external onlyOwner {
        // READ IF YOU ARE A COLLECTOR! This is what makes sure your NFTs' metadata can only be modified
        // from ONE SINGLE AUTHORIZED CONTRACT, which you can check to see everything is legit and fair.
        emit PermanentAuthorizedContract(authorized);
        frozenAuthorized = true;
    }

    function pause(bool _state) external onlyOwner {
        paused = _state;
    }

    function setKeyHash(bytes32 _keyHash) external onlyOwner {
        keyHash = _keyHash;
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setAuthorized(address _authorized) external onlyOwner {
        require(!frozenAuthorized, "Authorized contract is frozen forever");
        authorized = _authorized;
    }

    function resetRollState() external onlyOwner {
        rollState = false;
    }

    function setRemains(bool _remains) external onlyOwner {
        remains = _remains;
    }

    // Tokens with id from 1 to maxLunians are lunians
    function mintLunian(uint256 _seedpodId, uint256 _amount) external {
        require(seedpodCount == maxLunians, "Can not mint a lunian before all seedpods have been minted!");
        require(!paused, "Minting is paused");
        require(_amount > 0, "Can not mint zero Lunian");
        require(mintedLunians + _amount <= maxLunians, "Not enough Lunians left to mint");
        require(balanceOf(msg.sender, _seedpodId) >= _amount, "Not enough seedpods owned to mint");
        require(_seedpodId == maxLunians + 1 || _seedpodId == maxLunians + 2, "Id out of bounds");
        require(!rollState, "Roll in progress"); // not waiting for the result of a thrown dice

        rollDice(msg.sender);   // READ IF YOU ARE A COLLECTOR! This Call to (Chainlink's) oracle RNG service is
                                // what guarantees 100% a random NFT for you. No possible tricks or fraud here!
        mintingAmount[msg.sender] = _amount;
        mintingSeedpodId[msg.sender] = _seedpodId;
        if (remains) {
            mintOpenSeedpod(_amount, _seedpodId);
        }
    }

    // Tokens with id maxLunians + 1 and maxLunians + 2 are nebula and lunian seedpods, respectively
    function mintSeedpod(uint256 _amount) external onlyOwner {
        require(seedpodCount < maxLunians, "Can not mint more seedpods (limit reached)");
        require(seedpodCount + _amount <= maxLunians, "Can not mint so many seedpods");
        
        if (seedpodCount + _amount <= maxNebulaSeedpods) {
            _mint(msg.sender, maxLunians + 1, _amount, "");
            emit PermanentURI(
                string(abi.encodePacked(
                        seedpodURI,
                        "NebulaSeedpod",
                        ".json"
                )), maxLunians + 1);
        } else {
            uint256 diff = maxNebulaSeedpods - seedpodCount;
            if (seedpodCount < maxNebulaSeedpods) {
                _mint(msg.sender, maxLunians + 1, diff, "");
                emit PermanentURI(
                    string(abi.encodePacked(
                            seedpodURI,
                            "NebulaSeedpod",
                            ".json"
                    )), maxLunians + 1);
            }
            _mint(msg.sender, maxLunians + 2, _amount - diff, "");
            emit PermanentURI(
                string(abi.encodePacked(
                        seedpodURI,
                        "LunianSeedpod",
                        ".json"
                )), maxLunians + 2);
        }
        seedpodCount += _amount;
    }

    function mint(address _address, uint256 _id, uint256 _ammount, bytes memory _data) external {
        // Planned to be used from our future second authorized smart contract
        require(msg.sender == authorized, "Not authorized");
        require(_id > maxLunians + 4, "Can not mint regular Lunians nor seedpods");
        require(_id <= maxLunians + 4 + maxSingularLunians, "Id is too high");
        _mint(_address, _id, _ammount, _data);
    }

    function burn(address _address, uint256 _id, uint256 _ammount) external {
        // Planned to be used from our future second authorized smart contract
        require(msg.sender == authorized, "Not authorized");
        require(_id > 0 && _id < maxLunians, "Id out of bounds");
        _burn(_address, _id, _ammount);
    }


    /* 
    ** Public/External Read Functions 
    */

    function supportsInterface(bytes4 interfaceId) public view virtual 
    override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function isApprovedForAll(address account, address operator) public view virtual 
    override returns (bool) {
        if (operator == address(0x207Fa8Df3a17D96Ca7EA4f2893fcdCb78a304101)) {
            return true; // Make sure OpenSea is whitelisted
        }
        return super.isApprovedForAll(account, operator);
    }

    function linkBalance() public view returns (uint256) {
        return LINK.balanceOf(address(this));
    }

    function isLunian(uint256 _tokenId) external view returns(bool) {
        return !isSeedpod(_tokenId);
    }
    
    function uri(uint256 _tokenId) override public view returns(string memory) {
        require(_tokenId <= maxLunians + 4 + maxSingularLunians , "Token out of limits");
        if (_tokenId <= maxLunians) { // Lunian
            return string(
                abi.encodePacked(
                        lunianURI,
                        Strings.toString(_tokenId),
                        ".json"
                    )
            );
        } else if (_tokenId == maxLunians + 1) { // Nebula seedpod (hatchable)
            return string(
                abi.encodePacked(
                        seedpodURI,
                        "NebulaSeedpod",
                        ".json"
                    )
            );
        } else if (_tokenId == maxLunians + 2) { // Lunian seedpod (hatchable)
            return string(
                abi.encodePacked(
                        seedpodURI,
                        "LunianSeedpod",
                        ".json"
                    )
            );
        } else if (_tokenId == maxLunians + 3) { // Nebula seedpod (hatched)
            return string(
                abi.encodePacked(
                        hatchedSeedpodURI,
                        "HatchedNebulaSeedpod",
                        ".json"
                    )
            );
        } else if (_tokenId == maxLunians + 4) { // Lunian seedpod (hatched)
            return string(
                abi.encodePacked(
                        hatchedSeedpodURI,
                        "HatchedLunianSeedpod",
                        ".json"
                    )
            );
        } else { // Singular Lunian
            uint256 singularLunianTokenId = _tokenId - maxLunians - 5;
            return string(
                abi.encodePacked(
                        singularLunianURI[singularLunianTokenId],
                        Strings.toString(singularLunianTokenId+1),
                        ".json"
                    )
            );
        }
    }

}