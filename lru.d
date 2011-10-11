module lru;
/** LRU (Least-recently used) cache implementation for D programming language. */

/* Lock-free algorithms
 *
 * TODO: An Optimistic Approach to Lock-Free FIFO Queues. Edya Lade-Mozes and Nir Shavit
 */

import std.c.time : time_t;

/** Wrapper for hashing
 *
 * Number of calls from SLRU in general:
 *
 * On every hit-read access: one opIn, two opIndexAssign (both overwrite)
 * On every miss-read access: one opIn
 * On every hit-write access: one opIn, two opIndexAssign (both overwrite)
 * On every miss-write access: one opIn, one opIndexAssign and additional opIndexAssign on overflow
 *
 * For hash tables hit calls can be optimized (keys are the same in opIn/remove/opIndexAssign and remove/opIndexAssign).
 */
struct Hash(K,V) {
	private V[K] h;
	V opIndex(K x) {
		return h[x];
	}
	void opIndexAssign(V v1, K x) {
		h[x] = v1;
	}
	V* opIn(K x) {
		return (x in h);
	}
	void remove(K x) {
		h.remove(x);
	}
}

/** Strict Last Recently Used cache
 *
 * After every access (we are using builtin associative arrays)
 * We move element in front of list
 * If we are going to be full, we remove last element
 *
 * Retrive: O(1)
 * Store: O(1)
 * Remove Last: O(1)
 *
 * assuming that AA are implemented as hash tables.
 *
 * Note: if they are trees, all operations are O(log n)
 *
 * TODO: it is not thread safe.
 *
 * TODO: remove more than one based on size of V and K
 */
class SLRU(K,V) {
	// it is unidirectional linked list with head
	// we are operating using Node*p, but semanticly
	// value of it is p.prev.{k,v}
	/*
	 * n1(front) <- n2 <- n3 <- n4 <- rear
	 * rear.remove()
	 * n1(front) <- n2 <- n3 <- rear
	 * attachatfront()
	 * n0(front) <- n1 <- n2 <- n3 <- rear
	*/
	private struct Node {
		K k;
		V v;
		Node* prev;
		size_t hit;
		time_t atime;
	}

	// this hash is to previous value
	alias Hash!(K, Node*) Container;

	// actuall value is at c[k].prev.v
	private Container c;

	// fifo
	private Node* front, rear; // first element and after last element
	bool isEmpty() { return (front is rear); }

	private size_t elems;
	private size_t size;
	private size_t limit;

	union {
		struct {
			private size_t miss;
			private size_t hit;
		}
		private size_t[2] misshit;
	}

	this(size_t limit_ = 65536) {
		limit = limit_;
		front = rear = new Node();
	}

	Node* dirty_idx(K k) {
		auto p = c.opIn(k);
		if (!p) {
			return null;
		}
		Node* n = *p;
		return n.prev;
	}


	Node* idx(K k) {
		auto p = c.opIn(k);
		if (!p) {
			return null;
		}
		Node* n = *p;
		synchronized {
			// before: n1(front) <- n2 <- n3 <- d[n3.k] <- n[k] <- n6 <- rear
			Node* d = n.prev; // detached n
			d.hit++;
			if (d is front) { // if we are on front, we don't need to rearange antything
				return d;
			}
			// temp: n1(front) <- n2 <- n3 <- d(n.prev)[n3.k] <- n[k] <- n6 <- rear
			n.prev = n.prev.prev; // remove n
			// temp: n1(front) <- n2 <- n3(n.prev) <- n[k] <- n6 <- rear
			Node* newn = front; // remember current front
			// temp: n1(newn,front)[n3.k] <- n2 <- n3(n.prev) <- n[k] <- n6 <- rear
			newn.prev = d; // attach n befor current front
			// temp: n3 <- d(newn.prev)[n3.k] <- n1(newn,front) <- n2 <- n3(n.prev) <- n[k] <- n6 <- rear
			front = d; // add as front
			version(release) {
			} else {
				d.prev = null; // for invariant
			}
			// temp: d(front,newn.prev)[n3.k] <- n1(newn) <- n2 <- n3(n.prev) <- n[k] <- n6 <- rear
			//c.remove(k); // remove from index key k (which was pointing to n)
			// temp: d(front,newn.prev)[n3.k] <- n1(newn) <- n2 <- n3(n.prev) <- n <- n6 <- rear
			c[k] = newn; // add newn as k
			// temp: d(front,newn.prev)[n3.k] <- n1(newn)[k==d.k] <- n2 <- n3(n.prev) <- n <- n6 <- rear
			assert(c[k].prev.k == k);
			//c.remove(n.prev.k);
			// temp: d(front,newn.prev) <- n1(newn)[k] <- n2 <- n3(n.prev) <- n <- n6 <- rear
			c[n.prev.k] = n;
			// temp: d(front,newn.prev) <- n1(newn)[k,d.k] <- n2 <- n3(n.prev) <- n[n.prev.kn3.k] <- n6 <- rear
			assert(d.k == k);
			// after: d(front) <- n1[d.k] <- n2 <- n3 <- n[n3.k] <- n6 <- rear
			return d;
		}
	}

	V opIndex(K k) {
		Node* d = idx(k);
		misshit[d !is null]++;
		return (d !is null ? d.v : null);
	}

	void removeLast() {
		if (! isEmpty()) {
			synchronized {
				// before: n1(front) <- n2 <- n3(p.prev) <- p[n3.k] <- rear[p.k]
				Node* p = rear.prev; // detached last
				writefln("Usuwam: %s", p.k);
				// temp: n1(front) <- n2 <- n3(p.prev) <- p[n3.k] <- rear[p.k]
				rear.prev = p.prev; // remove last
				// temp: n1(front) <- n2 <- n3(p.prev) <- rear[p.k]
				//c.remove(p.prev.k); // remove
				// temp: n1(front) <- n2 <- n3(p.prev) <- rear[p.k]
				c[p.prev.k] = rear;
				// temp: n1(front) <- n2 <- n3(p.prev) <- rear[n3.k]
				c.remove(p.k);
				size -= p.v.length;
				delete p;
				// after: n1(front) <- n2 <- n3(rear.prev) <- rear
				elems--;
			}
		}
	}

	invariant() {
		assert(front.prev is null);
	}

	void opIndexAssign(V v, K k) {
		Node* p = idx(k);
		if (!p) { // no such key
			while (elems >= limit) {
				removeLast();
			}
			p = new Node();
			p.v = v;
			p.k = k;
			synchronized {
				// before: n1(front) <- n2 <- n3 <- n4 <- rear
				Node* old = front;
				// temp: n1(front,old) <- n2 <- n3 <- n4 <- rear
				old.prev = p;
				// temp: p(old.prev) <- n1(front,old) <- n2 <- n3 <- n4 <- rear
				front = p;
				// temp: p(front,old.prev) <- n1(old) <- n2 <- n3 <- n4 <- rear
				c[k] = old;
				// after: p(front,old.prev) <- n1(old)[k] <- n2 <- n3 <- n4 <- rear
				elems++;
				size += v.length;
			}
		} else {
			synchronized {
				size -= p.v.length;
				p.v = v;
				size += v.length;
			}
		}
	}

	synchronized void print() {
		Node* cur = rear;
		int i;
		while (cur.prev) {
			cur = cur.prev;
			writefln("%d k=%s v=%s hit=%d", i++, cur.k, cur.v, cur.hit);
		}
	}
}
