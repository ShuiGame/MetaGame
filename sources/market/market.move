module shui_module::market {
    use std::string;
    use sui::kiosk::{Self};
    use shui_module::boat_ticket::{Self};
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::object::{Self, ID};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use shui_module::royalty_policy::{Self};
    use shui_module::metaIdentity::{MetaIdentity};
    use shui_module::tree_of_life::{Self};
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap,
        TransferRequest,
        remove_rule
    };

    struct ItemListed has copy, drop {
        kioskId:vector<u8>,
        name:string::String,
        index: u64,
        owner:address,
        price:u64,
        num:u64
    }

    struct GameItemsCredential has key, store {
        id: UID,
        name: string::String,
        num: u64
    }

    struct ItemWithdrew has copy, drop  {
        kioskId:vector<u8>,
        // purchased / withdrew
        reason:string::String
    }

    public fun place_and_list_game_items<T: key + store>(meta:&mut MetaIdentity, total_price: u64, name:string::String, num:u64, ctx: &mut TxContext) {
        // extract and drop items
        tree_of_life::extract_drop_items(meta, name, num);

        // create virtual nft credential
        let virtualCredential = GameItemsCredential {
            id: object::new(ctx),
            name: name,
            num: num
        }

        // list_to_market
        let (kiosk, cap) = kiosk::new(ctx);
        kiosk::place_and_list(&mut kiosk, &cap, virtualCredential, total_price);        

        // 发送事件
        event::emit(
            ItemListed {
                kioskId:object::uid_to_bytes(kiosk::uid(&kiosk)),
                name: name,
                num: num,
                index: 0,
                owner: tx_context::sender(ctx),
                price: total_price
            }
        );
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::public_transfer(kiosk, tx_context::sender(ctx));
    }

    public fun place_and_list_boat_ticket(item: boat_ticket::BoatTicket, price: u64, ctx:&mut TxContext) {
        // todo:bind everycount to an certain kiosk
        let (kiosk, cap) = kiosk::new(ctx);
        let index = boat_ticket::get_index(&item);
        kiosk::place_and_list(&mut kiosk, &cap, item, price);
        event::emit(
            ItemListed {
                kioskId:object::uid_to_bytes(kiosk::uid(&kiosk)),
                name: string::utf8(b"starship summons"),
                index: index,
                owner: tx_context::sender(ctx),
                price: price,
                num: 1
            }
        );
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::public_transfer(kiosk, tx_context::sender(ctx));
    }

    public fun buy_game_items(meta:&mut MetaIdentity, policy: &mut TransferPolicy<GameItemsCredential>, kiosk: &mut kiosk::Kiosk, id:ID, payment:Coin<SUI>, ctx: &mut TxContext) {
        let gameCredential, transferRequst) = kiosk::purchase<GameItemsCredential>(kiosk, id, payment);
        let royalty_pay = coin::zero<SUI>(ctx);
        royalty_policy::pay(policy, &mut transferRequst, &mut royalty_pay, ctx);
        coin::destroy_zero(royalty_pay);
        policy::confirm_request(policy, transferRequst);
        let GameItemsCredential {id, name, num} = gameCredential;
        object::delete(id);

        // create and add to items
        tree_of_life::fill_items(mata, name, num);
        event::emit(
            ItemWithdrew {
                kioskId:object::uid_to_bytes(kiosk::uid(kiosk)),
                reason:string::utf8(b"withdrew")
            }
        );
    }

    // todo:how to pre get the kiosk price before calling the purchase function
    public fun buy_nft(policy: &mut TransferPolicy<boat_ticket::BoatTicket>, kiosk: &mut kiosk::Kiosk, id:ID, payment:Coin<SUI>, ctx: &mut TxContext) {
        let (nft, transferRequst) = kiosk::purchase<boat_ticket::BoatTicket>(kiosk, id, payment);
        let royalty_pay = coin::zero<SUI>(ctx);
        royalty_policy::pay(policy, &mut transferRequst, &mut royalty_pay, ctx);
        coin::destroy_zero(royalty_pay);
        policy::confirm_request(policy, transferRequst);
        transfer::public_transfer(nft, tx_context::sender(ctx));
        event::emit(
            ItemWithdrew {
                kioskId:object::uid_to_bytes(kiosk::uid(kiosk)),
                reason:string::utf8(b"withdrew")
            }
        );
    }

    public fun take_and_transfer(kiosk: &mut kiosk::Kiosk, cap: &kiosk::KioskOwnerCap, item: address, ctx: &mut TxContext) {
        let nft = kiosk::take<boat_ticket::BoatTicket>(kiosk, cap, object::id_from_address(item));
        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    public fun close_and_withdraw(kiosk: kiosk::Kiosk, cap: kiosk::KioskOwnerCap, ctx: &mut TxContext) {
        event::emit(
            ItemWithdrew {
                kioskId:object::uid_to_bytes(kiosk::uid(&kiosk)),
                reason:string::utf8(b"close")
            }
        );
        let sui = kiosk::close_and_withdraw(kiosk, cap, ctx);
        transfer::public_transfer(sui, tx_context::sender(ctx));
    }
}