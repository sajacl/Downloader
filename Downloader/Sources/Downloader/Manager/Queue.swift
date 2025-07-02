import Foundation

extension Downloader.Manager {
    /// Simple pull based queue.
    struct Queue<Element>: Sequence {
        private var storage: _Queue<Element>
        
        /// Computed property indicating is the queue empty.
        var isEmpty: Bool {
            storage.isEmpty
        }

        /// Method to add a new `Element` to the queue.
        mutating func enqueue(_ value: Element) {
            if isKnownUniquelyReferenced(&storage) {
                storage.enqueue(value: value)
            } else {
                let newStorage = storage.copy()

                newStorage.enqueue(value: value)

                storage = newStorage
            }
        }

        /// Method to retrieve a value from the queue.
        mutating func dequeue() -> Element? {
            if isKnownUniquelyReferenced(&storage) {
                return storage.dequeue()
            } else {
                let newStorage = storage.copy()

                storage = newStorage

                return newStorage.dequeue()
            }
        }

        // Sequence conformance

        func makeIterator() -> some IteratorProtocol {
            storage.makeIterator()
        }
    }
}

private final class _Queue<Element>: Sequence {
    private var head: Node?

    private var tail: Node?

    var isEmpty: Bool {
        head == nil
    }

    func enqueue(value: Element) {
        let newNode = Node(element: value)

        _enqueue(node: newNode)
    }

    private func _enqueue(node: Node) {
        if let _tail = tail {
            _tail.next = node
            node.previous = _tail

            tail = node
        } else {
            head = node
            tail = node
        }
    }

    func dequeue() -> Element? {
        _dequeue()?.element
    }

    private func _dequeue() -> Node? {
        if let _head = head {
            let next = _head.next

            head = next
            next?.previous = nil
            _head.next = nil

            return _head
        }

        return nil
    }

    func makeIterator() -> Iterator {
        Iterator(queue: self)
    }

    struct Iterator: IteratorProtocol {
        private var current: Node?

        init(queue: _Queue) {
            self.current = queue.head
        }

        mutating func next() -> Element? {
            defer { current = current?.next }

            return current?.element
        }
    }

    func copy() -> _Queue<Element> {
        let newQueue = _Queue<Element>()

        var current = head

        while let node = current {
            newQueue.enqueue(value: node.element)
            current = node.next
        }

        return newQueue
    }

    final class Node {
        let element: Element

        var next: Node?

        var previous: Node?

        init(element: Element, next: Node? = nil, previous: Node? = nil) {
            self.element = element
            self.next = next
            self.previous = previous
        }
    }
}
