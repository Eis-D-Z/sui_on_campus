module contracts::vault;

use std::type_name::{Self, TypeName};
use sui::balance::Balance;
use sui::coin::Coin;
use sui::dynamic_field as df;
use sui::table::{Table, new};


// Structs
public struct Vault has key, store {
    id: UID,
    stakers: Table<address, u64>,
    admin: address,
}

public struct StakeProof<phantom T> has key, store {
    id: UID,
    amount: u64
}

fun init(ctx: &mut TxContext) {
    let vault = Vault {
        id: object::new(ctx),
        stakers: new<address, u64>(ctx),
        admin: ctx.sender(),
    };

    transfer::public_share_object(vault);
}

// Functions
// 0x2::sui::SUI 0x232423423432::usdc::USDC
public fun add_new_coin<T>(
    vault: &mut Vault,
    coin: Coin<T>,
    ctx: &mut TxContext,
) {
    assert!(ctx.sender() == vault.admin, 1);
    let name = type_name::get<T>();
    let bal = coin.into_balance();

    df::add<TypeName, Balance<T>>(&mut vault.id, name, bal);
}

public fun withdraw_coin<T>(vault: &mut Vault, ctx: &mut TxContext): Coin<T> {
    assert!(vault.admin == ctx.sender(), 1);
    let name = type_name::get<T>();
    assert!(df::exists_(&vault.id, name), 2);
    let bal = df::borrow_mut<TypeName, Balance<T>>(&mut vault.id, name);
    let amount = bal.value();
    let return_bal = bal.split(amount);
    return_bal.into_coin(ctx)
}

//User function

public fun stake<T>(vault: &mut Vault, coin: Coin<T>, ctx: &mut TxContext): StakeProof<T> {
    let name = type_name::get<T>();
    assert!(df::exists_(&vault.id, name), 2);

    let sender = ctx.sender();
    let amount = coin.value();
    
    if (vault.stakers.contains(sender)) {
        let original_amount = *vault.stakers.borrow<address, u64>(sender);
        *vault.stakers.borrow_mut(sender) = original_amount + amount;

    } else {
        vault.stakers.add(sender, amount);
    };

    let user_bal = coin.into_balance();
    let vault_bal = df::borrow_mut<TypeName, Balance<T>>(&mut vault.id, name);

    vault_bal.join(user_bal);

    StakeProof<T> {
        id: object::new(ctx),
        amount
    }
    
}