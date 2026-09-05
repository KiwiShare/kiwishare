import mongoose, { ClientSession } from 'mongoose';

type TransactionWork<T> = (session: ClientSession | null) => Promise<T>;

const standaloneClients = new WeakSet<object>();

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

/**
 * Use MongoDB transactions when the connected deployment supports them.
 * The default local URI commonly points at a standalone mongod, so fall back
 * to the same ordered writes there instead of making chat unusable.
 */
export async function runMongoTransaction<T>(
  work: TransactionWork<T>
): Promise<T> {
  const client = mongoose.connection.getClient() as unknown as object;
  if (standaloneClients.has(client)) return work(null);

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
    // topology result per MongoClient and execute the ordered fallback once.
    standaloneClients.add(client);
    return work(null);
  } finally {
    await session.endSession();
  }
}
