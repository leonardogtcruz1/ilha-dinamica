import SwiftUI

struct NotesExpandedView: View {
    @ObservedObject var notes: NotesService
    @ObservedObject var coordinator: IslandCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(NotesSubTab.allCases) { sub in
                        let selected = notes.activeSubTab == sub
                        Button {
                            notes.activeSubTab = sub
                        } label: {
                            Text(sub.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(selected ? .black : Color.white.opacity(0.72))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(selected ? Color.white : Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if notes.activeSubTab == .todos && notes.todos.contains(where: \.isDone) {
                    Button {
                        notes.clearCompleted()
                    } label: {
                        Text("Limpar feitas")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.60))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                } else if notes.activeSubTab == .scratchpad && !notes.quickNote.isEmpty {
                    Button {
                        notes.quickNote = ""
                    } label: {
                        Text("Limpar")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.60))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if notes.activeSubTab == .todos {
                todosView
            } else {
                scratchpadView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            coordinator.focusPanelForTyping()
        }
    }

    private var todosView: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                TextField("Adicionar tarefa...", text: $notes.draftTodoText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .onSubmit {
                        notes.addTodo()
                    }
                    .onTapGesture {
                        coordinator.focusPanelForTyping()
                    }

                Button {
                    notes.addTodo()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 27, height: 27)
                        .background(Color(red: 1.0, green: 0.78, blue: 0.24), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if notes.todos.isEmpty {
                VStack(spacing: 4) {
                    Text("Nenhuma tarefa pendente")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.60))
                    Text("Digite acima e pressione Enter para adicionar.")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 5) {
                        ForEach(notes.todos) { item in
                            todoRow(item)
                        }
                    }
                }
            }
        }
    }

    private func todoRow(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Button {
                notes.toggle(item)
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.isDone ? Color(red: 0.22, green: 0.90, blue: 0.48) : Color.white.opacity(0.45))
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(item.isDone ? Color.white.opacity(0.40) : .white)
                .strikethrough(item.isDone)
                .lineLimit(1)

            Spacer()

            Button {
                notes.delete(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var scratchpadView: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $notes.quickNote)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.75)
                )
                .onTapGesture {
                    coordinator.focusPanelForTyping()
                }

            if notes.quickNote.isEmpty {
                Text("Escreva um rascunho rápido (salvo automaticamente)...")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.white.opacity(0.36))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
