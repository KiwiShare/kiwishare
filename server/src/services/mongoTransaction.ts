import mongoose, { ClientSession } from 'mongoose';

type TransactionWork<T> = (session: ClientSession | null) => Promise<T>;

const standaloneClients = new WeakSet<object>();
const standaloneTails = new WeakMap<object, Promise<void>>();

async function runStandalone<T>(
  client: object,
  work: TransactionWork<T>
): Promise<T> {
  const ready = (standaloneTails.get(client) ?? Promise.resolve()).catch(
    () => undefined
  );
  let release!: () => void;
  const slot = new Promise<void>((resolve) => {
    release = resolve;
  });
  const tail = ready.then(() => slot);
  standaloneTails.set(client, tail);

  await ready;
  try {
    return await work(null);
  } finally {
    release();
    if (standaloneTails.get(client) === tail) standaloneTails.delete(client);
  }
}

function isTransactionUnsupported(error: unknown): boolean {
  const mongoError = error as {
    code?: unknown;
    codeName?: unknown;
    message?: unknown;
  };
  return (
    mongoError.code === 20 ||
    mongoError.codeName === 'IllegalOperation' ||
    (typeof mongoError.message === 'string' &&
      mongoError.message.includes(
        'Transaction numbers are only allowed on a replica set member or mongos'
      ))
  );
}

export class MongoTransactionsRequiredError extends Error {
  constructor() {
    super('This operation requires a transaction-capable MongoDB deployment.');
    this.name = 'MongoTransactionsRequiredError';
  }
}

/**
 * Run integrity-critical work only when MongoDB can commit every write as one
 * transaction. Unlike runMongoTransaction, this deliberately has no
 * standalone fallback because a partial handover or credit award is unsafe.
 */
export async function runRequiredMongoTransaction<T>(
  work: (session: ClientSession) => Promise<T>
): Promise<T> {
  const session = await mongoose.startSession();
  try {
    let result!: T;
    await session.withTransaction(async () => {
      result = await work(session);
    });
    return result;
  } catch (error) {
    if (isTransactionUnsupported(error)) {
      throw new MongoTransactionsRequiredError();
    }
    throw error;
  } finally {
    await session.endSession();
  }
}

/**
 * Use MongoDB transactions when the connected deployment supports them.
 * The default local URI commonly points at a standalone mongod, so fall back
 * to the same ordered writes there instead of making chat unusable.
 */
export async function runMongoTransaction<T>(
  work: TransactionWork<T>
): Promise<T> {
  const client = mongoose.connection.getClient() as unknown as object;
  if (standaloneClients.has(client)) return runStandalone(client, work);

  const session = await mongoose.startSession();
  try {
    let result!: T;
    await session.withTransaction(async () => {
      result = await work(session);
    });
    return result;
  } catch (error) {
    if (!isTransactionUnsupported(error)) throw error;
    // Code 20 is raised before a transaction operation is applied. Cache the
    // topology result per MongoClient and serialize its ordered fallback.
    standaloneClients.add(client);
    return runStandalone(client, work);
  } finally {
    await session.endSession();
  }
}
