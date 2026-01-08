import SwiftUI

struct WelcomeScreen: View {
    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0
    
    let pages = [
        WelcomePage(
            title: "Reclaim Your Day",
            subtitle: "Task Scheduler transforms your calendar from a list of 'times I'm busy' into a blueprint for precise productivity.",
            image: "sparkles",
            color: Color(hex: "8B5CF6")
        ),
        WelcomePage(
            title: "Smart Concepts",
            subtitle: "We protect your focus blocks (#work), prioritize your deep work (#deep), and handle your life admin (#side).",
            image: "brain.head.profile",
            color: Color(hex: "3B82F6")
        ),
        WelcomePage(
            title: "Respects Your Schedule",
            subtitle: "We analyze your existing calendar and perfectly fit new tasks into the available gaps. Your busy slots are always protected.",
            image: "calendar.badge.shield",
            color: Color(hex: "10B981")
        ),
        WelcomePage(
            title: "Plan with Clarity",
            subtitle: "Each day starts with a Planning session. Visualize your productivity gains before you even start.",
            image: "calendar.badge.clock",
            color: Color(hex: "EF4444")
        )
    ]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(hex: "0F172A"), Color(hex: "1E293B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 10) {
                // Header
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(8)
                            .background(Circle().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                // Content
                ZStack {
                    ForEach(0..<pages.count, id: \.self) { index in
                        if currentPage == index {
                            pageView(for: pages[index])
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                                    removal: .opacity.combined(with: .move(edge: .leading))
                                ))
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // Interactivity / Concepts
                Group {
                    if currentPage == 1 {
                        conceptsInteractiveView
                            .transition(.scale.combined(with: .opacity))
                    } else if currentPage == 2 {
                        calendarFittingView
                            .transition(.push(from: .bottom).combined(with: .opacity))
                    } else if currentPage == 3 {
                        productivityGainView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Spacer().frame(height: 120)
                    }
                }
                .frame(height: 120)
                .padding(.bottom, 48)
                
                // Footer
                VStack(spacing: 24) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[index].color : Color.white.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    HStack(spacing: 16) {
                        if currentPage > 0 {
                            Button {
                                withAnimation { currentPage -= 1 }
                            } label: {
                                Text("Back")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white.opacity(0.6))
                                    .frame(width: 100)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button {
                            if currentPage < pages.count - 1 {
                                withAnimation { currentPage += 1 }
                            } else {
                                dismiss()
                            }
                        } label: {
                            Text(currentPage == pages.count - 1 ? "Start Planning" : "Next")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: currentPage > 0 ? 180 : 280)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(pages[currentPage].color)
                                        .shadow(color: pages[currentPage].color.opacity(0.4), radius: 10, y: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .frame(width: 500, height: 750)
    }
    
    private func pageView(for page: WelcomePage) -> some View {
        VStack(spacing: 16) {
            Image(systemName: page.image)
                .font(.system(size: 72))
                .foregroundColor(page.color)
                .symbolEffect(.bounce, value: currentPage)
            
            VStack(spacing: 12) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(page.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private var conceptsInteractiveView: some View {
        HStack(spacing: 20) {
            conceptCard(title: "Focus", icon: "briefcase.fill", color: Color(hex: "8B5CF6"), tag: "#work")
            conceptCard(title: "Deep Work", icon: "bolt.circle.fill", color: Color(hex: "10B981"), tag: "#deep")
            conceptCard(title: "Admin/Side", icon: "star.fill", color: Color(hex: "3B82F6"), tag: "#side")
        }
        .frame(height: 120)
    }
    
    private var calendarFittingView: some View {
        HStack(spacing: 12) {
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)).frame(height: 30)
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: "8B5CF6")).frame(height: 40)
                    .overlay(Text("Work").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
                RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.1)).frame(height: 30)
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: "3B82F6")).frame(height: 30)
                    .overlay(Text("Side").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
            }
            .frame(width: 120)
            .padding(8)
            .background(Color.white.opacity(0.05))
            .cornerRadius(10)
            
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle().fill(Color.white.opacity(0.1)).frame(width: 12, height: 12)
                    Text("Existing events").font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                }
                HStack(spacing: 8) {
                    Circle().fill(Color(hex: "8B5CF6")).frame(width: 12, height: 12)
                    Text("Smart placement").font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .frame(height: 120)
    }
    
    private func conceptCard(title: String, icon: String, color: Color, tag: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text(tag)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.2))
                .foregroundColor(color)
                .cornerRadius(4)
        }
        .frame(width: 100, height: 110)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var productivityGainView: some View {
        VStack(spacing: 16) {
            Text("Potential Productivity Gain")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            
            HStack(alignment: .bottom, spacing: 12) {
                productivityBar(label: "Random", value: 0.4, color: .gray)
                productivityBar(label: "Planned", value: 0.95, color: Color(hex: "10B981"), isHighlight: true)
            }
            .frame(height: 80)
            
            Text("By eliminating decision fatigue, you regain up to 2 hours of pure focus daily.")
                .font(.system(size: 12))
                .italic()
                .foregroundColor(Color(hex: "10B981").opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
        .padding(.horizontal, 40)
    }
    
    private func productivityBar(label: String, value: CGFloat, color: Color, isHighlight: Bool = false) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 40, height: 60)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 40, height: 60 * value)
                    .shadow(color: color.opacity(isHighlight ? 0.5 : 0), radius: 5)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

struct WelcomePage {
    let title: String
    let subtitle: String
    let image: String
    let color: Color
}

#Preview {
    WelcomeScreen()
}
