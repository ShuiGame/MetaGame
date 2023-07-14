
module shui_module::items {
    use sui::bag::{Self};
    use sui::object::{Self, UID};
    use std::vector::{Self};
    use std::string;
    use sui::tx_context::{TxContext};
    friend shui_module::metaIdentity;
    friend shui_module::tree_of_life;

    const ERR_ITEMS_VEC_NOT_EXIST:u64 = 0x001;
    const ERR_ITEMS_NOT_EXIST:u64 = 0x002;
    const ERR_ITEMS_NOT_ENOUGH:u64 = 0x003;

    struct Items has key, store {
        id:UID,
        bags:bag::Bag,
    }

    public(friend) fun new(ctx:&mut TxContext): Items {
        Items {
            id: object::new(ctx),
            bags:bag::new(ctx)
        }
    }

    public(friend) fun destroy_empty(items: Items) {
        let Items {id, bags:bags} = items;
        object::delete(id);
        bag::destroy_empty(bags);
    }



    public(friend) fun store_item<T:store>(items: &mut Items, name:string::String, item:T) {
        if (bag::contains(&mut items.bags, name)) {
            let vec = bag::borrow_mut(&mut items.bags, name);
            vector::push_back(vec, item);
        } else {
            let vec = vector::empty<T>();
            vector::push_back(&mut vec, item);
            bag::add(&mut items.bags, name, vec);
        }
    }

    public(friend) fun store_items<T:store>(items: &mut Items, name:string::String, item_arr: vector<T>) {
        if (bag::contains(&mut items.bags, name)) {
            let vec = bag::borrow_mut(&mut items.bags, name);
            let (i, len) = (0u64, vector::length(&item_arr));
            while (i < len) {
                let item:T = vector::pop_back(&mut item_arr);
                vector::push_back(vec, item);
                i = i + 1
            };
        } else {
            let vec = vector::empty<T>();
            let (i, len) = (0u64, vector::length(&item_arr));
            while (i < len) {
                let item:T = vector::pop_back(&mut item_arr);
                vector::push_back(&mut vec, item);
                i = i + 1
            };
            bag::add(&mut items.bags, name, vec);
        };
        vector::destroy_empty(item_arr);
    }

    public(friend) fun extract_item<T:store>(items: &mut Items, name:string::String): T {
        assert!(bag::contains(&items.bags, name), ERR_ITEMS_VEC_NOT_EXIST);
        let vec:&mut vector<T> = bag::borrow_mut(&mut items.bags, name);
        assert!(vector::length(vec) > 0, ERR_ITEMS_NOT_EXIST);
        vector::pop_back(vec)
    }

    public(friend) fun extract_items<T:store>(items: &mut Items, name:string::String, num:u64): vector<T> {
        assert!(bag::contains(&items.bags, name), ERR_ITEMS_VEC_NOT_EXIST);
        let vec:&mut vector<T> = bag::borrow_mut(&mut items.bags, name);
        assert!(vector::length(vec) >= num, ERR_ITEMS_NOT_ENOUGH);
        let extra_vec = vector::empty();
        let i = 0u64;
        while (i < num) {
            let item:T = vector::pop_back(vec);
            vector::push_back(&mut extra_vec, item);
            i = i + 1
        };
        extra_vec
    }
}