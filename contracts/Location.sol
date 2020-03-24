// File: contracts/Thing.sol
pragma solidity ^0.5.0;

import "@openzeppelin/contracts/GSN/Context.sol";

import "@openzeppelin/contracts/introspection/IERC165.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/drafts/Counters.sol";

import "@openzeppelin/contracts/introspection/ERC165.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";

import "@openzeppelin/contracts/access/Roles.sol";

import "@openzeppelin/contracts/access/roles/MinterRole.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721MetadataMintable.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

library Strings {
    // via https://github.com/oraclize/ethereum-api/blob/master/oraclizeAPI_0.5.sol
    function strConcat(
        string memory _a,
        string memory _b,
        string memory _c,
        string memory _d,
        string memory _e
    ) internal pure returns (string memory) {
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        bytes memory _bc = bytes(_c);
        bytes memory _bd = bytes(_d);
        bytes memory _be = bytes(_e);
        string memory abcde = new string(
            _ba.length + _bb.length + _bc.length + _bd.length + _be.length
        );
        bytes memory babcde = bytes(abcde);
        uint256 k = 0;
        for (uint256 i = 0; i < _ba.length; i++) babcde[k++] = _ba[i];
        for (uint256 i = 0; i < _bb.length; i++) babcde[k++] = _bb[i];
        for (uint256 i = 0; i < _bc.length; i++) babcde[k++] = _bc[i];
        for (uint256 i = 0; i < _bd.length; i++) babcde[k++] = _bd[i];
        for (uint256 i = 0; i < _be.length; i++) babcde[k++] = _be[i];
        return string(babcde);
    }

    function strConcat(
        string memory _a,
        string memory _b,
        string memory _c,
        string memory _d
    ) internal pure returns (string memory) {
        return strConcat(_a, _b, _c, _d, "");
    }

    function strConcat(string memory _a, string memory _b, string memory _c)
        internal
        pure
        returns (string memory)
    {
        return strConcat(_a, _b, _c, "", "");
    }

    function strConcat(string memory _a, string memory _b)
        internal
        pure
        returns (string memory)
    {
        return strConcat(_a, _b, "", "", "");
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len - 1;
        while (_i != 0) {
            bstr[k--] = bytes1(uint8(48 + (_i % 10)));
            _i /= 10;
        }
        return string(bstr);
    }
}

contract Location is
    ERC721Full,
    ERC721MetadataMintable,
    ERC721Burnable,
    Ownable
{
    using SafeMath for uint256;
    using Strings for string;

    enum TokenState {Pending, ForSale, Sold, Transferred}

    struct Price {
        uint256 tokenId;
        uint256 price;
        string metaId;
        TokenState state;
    }

    mapping(uint256 => Price) public items;

    uint256 public id;
    string public baseUri;
    address payable public maker;
    address payable feeAddress;

    constructor(
        string memory name,
        string memory symbol,
        string memory uri,
        address payable fee,
        address payable creator
    ) public ERC721Full(name, symbol) {
        maker = creator;
        feeAddress = fee;
        baseUri = uri;
        id = 0;
        transferOwnership(creator);
        _addMinter(creator);

    }

    event ErrorOut(string error, uint256 tokenId);
    event BatchTransfered(string metaId, address[] recipients, uint256[] ids);
    event Minted(uint256 id, string metaId);
    event BatchBurned(string metaId, uint256[] ids);
    event BatchForSale(uint256[] ids, string metaId);
    event Bought(uint256 tokenId, string metaId, uint256 value);
    event Destroy();

    function tokenURI(uint256 _tokenId) public view returns (string memory) {
        return Strings.strConcat(baseUri, items[_tokenId].metaId);
    }

    function setTokenState(uint256[] memory ids, bool isEnabled)
        public
        onlyMinter
    {
        for (uint256 i = 0; i < ids.length; i++) {
            if (isEnabled == true) {
                items[ids[i]].state = TokenState.ForSale;
            } else {
                items[ids[i]].state = TokenState.Pending;
            }
        }
        emit BatchForSale(ids, items[ids[0]].metaId);
    }

    function setTokenPrice(uint256[] memory ids, uint256 setPrice)
        public
        onlyMinter
    {
        for (uint256 i = 0; i < ids.length; i++) {
            items[ids[i]].price = setPrice;
        }
    }

    function mintbaseFee(uint256 amount) internal pure returns (uint256) {
        uint256 toOwner = SafeMath.mul(amount, 2);

        return SafeMath.div(toOwner, 100);
    }

    function buyThing(uint256 _tokenId) public payable returns (bool) {
        require(msg.value >= items[_tokenId].price, "Price issue");
        require(TokenState.ForSale == items[_tokenId].state, "No Sale");

        if (items[_tokenId].price >= 0) {
            uint256 fee = mintbaseFee(msg.value);
            uint256 withFee = SafeMath.sub(msg.value, fee);

            maker.transfer(withFee);
            feeAddress.transfer(fee);
        }

        _transferFrom(maker, msg.sender, _tokenId);
        items[_tokenId].state = TokenState.Sold;

        emit Bought(_tokenId, items[_tokenId].metaId, msg.value);
    }

    function destroyAndSend() public onlyOwner {
        emit Destroy();
        selfdestruct(maker);
    }

    function batchTransfer(
        address giver,
        address[] memory recipients,
        uint256[] memory values
    ) public {
        for (uint256 i = 0; i < values.length; i++) {
            transferFrom(giver, recipients[i], values[i]);
            items[values[i]].state = TokenState.Transferred;
        }
        emit BatchTransfered(items[values[0]].metaId, recipients, values);
    }

    function batchMint(
        address to,
        uint256 amountToMint,
        string memory metaId,
        uint256 setPrice,
        bool isForSale
    ) public onlyMinter {
        require(amountToMint <= 40, "Over 40");

        for (uint256 i = 0; i < amountToMint; i++) {
            id = id.add(1);
            items[id].price = setPrice;
            items[id].metaId = metaId;
            if (isForSale == true) {
                items[id].state = TokenState.ForSale;

            } else {
                items[id].state = TokenState.Pending;
            }
            _mint(to, id);
            emit Minted(id, metaId);
        }

    }

    function batchBurn(uint256[] memory tokenIds) public onlyMinter {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _burn(tokenIds[i]);
        }
        emit BatchBurned(items[tokenIds[0]].metaId, tokenIds);
    }

    function tokensOfOwner(address owner)
        public
        view
        returns (uint256[] memory)
    {
        return _tokensOfOwner(owner);
    }
}
