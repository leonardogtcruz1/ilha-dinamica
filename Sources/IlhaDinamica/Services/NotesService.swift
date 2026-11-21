import Foundation

enum NotesSubTab: String, CaseIterable, Identifiable {
    case todos
    case scratchpad

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todos:
            return "Tarefas"
        case .scratchpad:
            return "Rascunho"
        }
    }
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isDone: Bool

    init(id: UUID = UUID(), title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

@MainActor
final class NotesService: ObservableObject {
    private enum Keys {
        static let todos = "notes.todos"
        static let quickNote = "notes.quickNote"
    }

    @Published var activeSubTab: NotesSubTab = .todos
    @Published var draftTodoText: String = ""
    @Published private(set) var todos: [TodoItem] = []
    @Published var quickNote: String {
        didSet {
            defaults.set(quickNote, forKey: Keys.quickNote)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.quickNote = defaults.string(forKey: Keys.quickNote) ?? ""
        loadTodos()
    }

    var pendingCount: Int {
        todos.filter { !$0.isDone }.count
    }

    func addTodo() {
        let trimmed = draftTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        todos.insert(TodoItem(title: trimmed), at: 0)
        draftTodoText = ""
        saveTodos()
    }

    func toggle(_ item: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == item.id }) else { return }
        todos[index].isDone.toggle()
        saveTodos()
    }

    func delete(_ item: TodoItem) {
        todos.removeAll { $0.id == item.id }
        saveTodos()
    }

    func clearCompleted() {
        todos.removeAll { $0.isDone }
        saveTodos()
    }

    private func loadTodos() {
        guard let data = defaults.data(forKey: Keys.todos),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        todos = decoded
    }

    private func saveTodos() {
        guard let encoded = try? JSONEncoder().encode(todos) else { return }
        defaults.set(encoded, forKey: Keys.todos)
    }
}
