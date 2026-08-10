using System;

namespace PanBeat.Domain
{
    public sealed class FixedObjectPool<T> where T : class
    {
        private readonly T[] items;
        private int count;

        public FixedObjectPool(int capacity, Func<T> factory)
        {
            if (capacity <= 0) throw new ArgumentOutOfRangeException(nameof(capacity));
            items = new T[capacity];
            for (var index = 0; index < capacity; index++) items[index] = factory();
            count = capacity;
        }

        public int Capacity => items.Length;
        public int Available => count;
        public long OverflowCount { get; private set; }

        public bool TryRent(out T item)
        {
            if (count == 0)
            {
                OverflowCount++;
                item = null;
                return false;
            }
            item = items[--count];
            items[count] = null;
            return true;
        }

        public void Return(T item)
        {
            if (item == null) throw new ArgumentNullException(nameof(item));
            if (count == items.Length) throw new InvalidOperationException("Pool is already full.");
            items[count++] = item;
        }
    }
}
