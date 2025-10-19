import { describe, it, expect } from 'vitest';
import { Cl } from '@stacks/transactions';

const accounts = simnet.getAccounts();
const addr1 = accounts.get('wallet_1')!;

describe('proposal comments', () => {
  it('returns 0 for proposals with no comments', () => {
    const { result } = simnet.callReadOnlyFn('DAO', 'get-comment-count', [Cl.uint(1)], addr1);
    expect(result).toBeUint(0);
  });
});
