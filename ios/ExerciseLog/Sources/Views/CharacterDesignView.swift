import SwiftUI

/// Tutorial Island's Character Design screen: the figure in the middle,
/// arrows to cycle each part's style on the left and its colour on the
/// right, a body-type toggle, and Accept.
struct CharacterDesignView: View {
    @EnvironmentObject private var store: LogStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = Avatar()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text("Name").rsText(16, color: RS.orange)
                        TextField("Player", text: $draft.name)
                            .textFieldStyle(.plain).rsText(18, color: RS.white).tint(RS.yellow)
                            .padding(6).stoneSlot()
                    }
                    .padding(10)
                    .stonePanel()

                    HStack(alignment: .top, spacing: 8) {
                        VStack(spacing: 6) {
                            Text("Style").rsText(16, color: RS.orange)
                            cycler("Head", Avatar.headStyles, $draft.head)
                            if !draft.female { cycler("Jaw", Avatar.jawStyles, $draft.jaw) }
                            cycler("Torso", Avatar.torsoStyles, $draft.torso)
                            cycler("Arms", Avatar.armStyles, $draft.arms)
                            cycler("Hands", Avatar.handStyles, $draft.hands)
                            cycler("Legs", Avatar.legStyles, $draft.legs)
                            cycler("Feet", Avatar.feetStyles, $draft.feet)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 6) {
                            AvatarView(avatar: draft, scale: 4)
                                .padding(8)
                                .parchmentPanel()
                            VStack(spacing: 4) {
                                Button("Male") { draft.female = false }
                                    .buttonStyle(StoneButton(color: draft.female ? RS.white : RS.green, fill: true))
                                Button("Female") { draft.female = true }
                                    .buttonStyle(StoneButton(color: draft.female ? RS.green : RS.white, fill: true))
                            }
                        }

                        VStack(spacing: 6) {
                            Text("Colour").rsText(16, color: RS.orange)
                            swatches("Hair", Avatar.hairColors, $draft.hairColor)
                            swatches("Torso", Avatar.clothColors, $draft.torsoColor)
                            swatches("Legs", Avatar.clothColors, $draft.legsColor)
                            swatches("Feet", Avatar.feetColors, $draft.feetColor)
                            swatches("Skin", Avatar.skinColors, $draft.skinColor)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(10)
                    .stonePanel()

                    Button("Accept") {
                        store.setAvatar(draft)
                        dismiss()
                    }
                    .buttonStyle(StoneButton(color: RS.orange, fill: true))
                }
                .padding(8)
            }
            .background(RS.darkImage().ignoresSafeArea())
            .navigationTitle("Character Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Cancel").rsText(18, color: RS.red) }
                }
            }
            .onAppear { draft = store.avatar }
        }
        .presentationCornerRadius(0)
    }

    private func cycler(_ label: String, _ options: [String], _ value: Binding<Int>) -> some View {
        VStack(spacing: 2) {
            Text(label).rsSmall(16, color: RS.orange)
            HStack(spacing: 4) {
                Button("<") { value.wrappedValue = (value.wrappedValue - 1 + options.count) % options.count }
                    .buttonStyle(StoneButton())
                Text(options[value.wrappedValue % options.count])
                    .rsSmall(16, color: RS.white).lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                Button(">") { value.wrappedValue = (value.wrappedValue + 1) % options.count }
                    .buttonStyle(StoneButton())
            }
        }
    }

    private func swatches(_ label: String, _ colors: [UInt32], _ value: Binding<Int>) -> some View {
        VStack(spacing: 2) {
            Text(label).rsSmall(16, color: RS.orange)
            HStack(spacing: 4) {
                Button("<") { value.wrappedValue = (value.wrappedValue - 1 + colors.count) % colors.count }
                    .buttonStyle(StoneButton())
                Rectangle().fill(Color(hex: colors[value.wrappedValue % colors.count]))
                    .frame(height: 24).frame(maxWidth: .infinity).bevel(inset: true)
                Button(">") { value.wrappedValue = (value.wrappedValue + 1) % colors.count }
                    .buttonStyle(StoneButton())
            }
        }
    }
}
