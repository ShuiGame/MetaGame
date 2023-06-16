module shui_module::tree_of_life {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::pay;
    use sui::coin::{Self, Coin, destroy_zero};
    use std::vector::{Self};
    use shui_module::shui::{SHUI};

    struct Tree_of_life has key, store {
        id:UID,
        level:u16,
        exp:u16,
    }

    public entry fun mint(ctx:&mut TxContext) {
        let tree = Tree_of_life {
            id:object::new(ctx),
            level:1,
            exp:0
        };
        transfer::public_transfer(tree, tx_context::sender(ctx));
    }

    public entry fun water_down(tree: &mut Tree_of_life, amount:u64, coins:vector<Coin<SHUI>>, ctx:&mut TxContext) {
        let merged_coin = vector::pop_back(&mut coins);
        pay::join_vec(&mut merged_coin, coins);
        assert!(coin::value(&merged_coin) >= amount, 1);
        let pay_coins = coin::split<SHUI>(&mut merged_coin, amount, ctx);
        transfer::public_transfer(pay_coins, @account);
        if (coin::value(&merged_coin) > 0) {
            transfer::public_transfer(merged_coin, tx_context::sender(ctx))
        } else {
            destroy_zero(merged_coin)
        };
        tree.exp = tree.exp + get_random_exp(amount);
    }

    // to be determined
    fun get_random_exp(amount:u64) :u16 {
        let u:u16 = 2;
        if (amount > 8) {
          return u
        };
        u
    }
}