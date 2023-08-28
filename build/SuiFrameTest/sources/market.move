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
        owner:address,
        price:u64
    }

    struct ItemWithdrew has copy, drop  {
        kioskId:vector<u8>,
        // purchased / withdrew
        reason:string::String
    }

    public fun place_and_list_nft(item: boat_ticket::BoatTicket, price: u64, ctx:&mut TxContext) {
        let (kiosk, cap) = kiosk::new(ctx);
        kiosk::place_and_list(&mut kiosk, &cap, item, price);
        
        event::emit(
            ItemListed {
                kioskId:object::uid_to_bytes(kiosk::uid(&kiosk)),
                name: string::utf8(b"item"),
                owner: tx_context::sender(ctx),
                price: price
            }
        );
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::public_transfer(kiosk, tx_context::sender(ctx));
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