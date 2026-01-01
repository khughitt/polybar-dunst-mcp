import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick.Effects
import "effects"

Scope {
	id: root

	// Terminal color palette for theming
	TerminalColors { id: termColors }

	QtObject {
		id: patternResolver
		function resolve(pattern) {
			if (!pattern || pattern === "") return "";
			if (pattern.indexOf("/") !== -1 || pattern.indexOf(":") !== -1) {
				return pattern;
			}
			return Qt.resolvedUrl("patterns/" + pattern + ".svg");
		}
	}

	QtObject {
		id: imageResolver
		function resolve(imageId) {
			if (!imageId || imageId === "") return "";
			if (imageId.indexOf("/") !== -1 || imageId.indexOf(":") !== -1) {
				return imageId;
			}
			return Qt.resolvedUrl("assets/" + imageId + ".svg");
		}
	}

	QtObject {
		id: accentPicker
		// Returns bright terminal color for UI elements (borders, text highlights)
		function forSeverity(severity) {
			return termColors.accentFor(severity);
		}
		// Returns normal terminal color for image tinting
		function tintForSeverity(severity) {
			return termColors.tintFor(severity);
		}
		function resolved(accent, severity) {
			if (accent && accent !== "") return accent;
			return forSeverity(severity);
		}
	}

	property bool visiblePopup: false
	property string title: ""
	property string body: ""
	property string severity: "info"
	property string pattern: ""
	property int timeoutSeconds: 8
	property string workspace: ""
	property string app: ""
	property string imageVariant: "ghost"
	property string transitionType: Quickshell.env("OHAI_TRANSITION") || "glow"
	property color accentColor: "#7ad7ff"
	property color tintColor: "#7aa2f7"  // Normal variant for image tinting
	property int popupVersion: 0

	// Shader effect properties (animated)
	property real chromaticAberration: 0.0
	property real shaderDisplacement: 0.0
	property real noiseAmount: 0.0
	property real scanlineAlpha: 0.0

	// Baseline noise level (persists throughout)
	property real baselineNoise: 0.045

	// Glitch noise burst (added on top of baseline during glitches)
	property real glitchNoiseBurst: 0.0

	// Signal to trigger exit animation (used by Timer and IPC from outside LazyLoader scope)
	signal requestExit()

	// IPC handler for receiving notifications from external processes
	IpcHandler {
		target: "ohai"

		function notify(
			title: string,
			body: string,
			severity: string,
			timeoutSeconds: int,
			pattern: string,
			image: string,
			workspace: string,
			app: string,
			color: string,
			transition: string
		): void {
			root.title = title || body;
			root.body = body;
			root.severity = severity || "info";
			root.pattern = pattern || "";
			root.imageVariant = image || "ghost";
			root.accentColor = accentPicker.resolved(color, root.severity);
			root.tintColor = accentPicker.tintForSeverity(root.severity);
			root.timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 8;
			root.workspace = workspace || "";
			root.app = app || "";
			root.transitionType = transition || Quickshell.env("OHAI_TRANSITION") || "glow";
			root.visiblePopup = true;

			if (root.timeoutSeconds > 0) {
				hideTimer.interval = root.timeoutSeconds * 1000;
				hideTimer.restart();
			} else {
				hideTimer.stop();
			}
			root.popupVersion += 1;
		}

		function hide(): void {
			root.requestExit();
		}
	}

	// Hide after timeout - trigger exit animation instead of immediate hide
	Timer {
		id: hideTimer
		interval: root.timeoutSeconds * 1000
		onTriggered: root.requestExit()
	}

	LazyLoader {
		active: root.visiblePopup

		PanelWindow {
			id: window
			anchors.right: true
			anchors.bottom: true
			margins.right: 24
			margins.bottom: 24

			// Padding around notification for glow effect overflow
			property int glowPadding: 60

			// Notification dimensions
			property int notificationWidth: 560
			property int notificationHeight: Math.min(contentColumn.implicitHeight + 48, 720)

			// Window sized to fit notification + ripple overflow
			implicitWidth: notificationWidth + 2 * glowPadding
			implicitHeight: notificationHeight + 2 * glowPadding
			exclusiveZone: 0
			color: "transparent"

			Item {
				id: panelContent
				anchors.fill: parent
				opacity: 0
				scale: 0.95
				focus: true
				Keys.onEscapePressed: exitAnimation.start()
				Keys.onPressed: {
					if (event.key === Qt.Key_QuoteLeft) {
						if (root.workspace !== "") {
							const cmd = ["hyprctl", "dispatch", "workspace", root.workspace];
							Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + '; running: true }', root);
						} else if (root.app !== "") {
							const cmd = ["hyprctl", "dispatch", "focuswindow", "title:" + root.app];
							Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + '; running: true }', root);
						}
						exitAnimation.start();
					}
				}

				// Transition effect - dynamic loader for glow/ghost/ripple effects
				TransitionLoader {
					id: transitionEffect
					anchors.centerIn: notificationContainer
					width: window.notificationWidth
					height: window.notificationHeight
					effectType: root.transitionType
					color: root.accentColor
					radius: 20
					sourceItem: notificationContainer
				}

				// Container for actual notification (positioned at bottom-right)
				Item {
					id: notificationContainer
					anchors.right: parent.right
					anchors.bottom: parent.bottom
					anchors.rightMargin: window.glowPadding
					anchors.bottomMargin: window.glowPadding
					width: window.notificationWidth
					height: window.notificationHeight

					// Click anywhere on notification to close
					MouseArea {
						anchors.fill: parent
						onClicked: exitAnimation.start()
						cursorShape: Qt.PointingHandCursor
					}

					Rectangle {
						id: backdrop
						anchors.fill: parent
						radius: 20
						color: "transparent"
						// Border removed for free-floating look

						// Apply glitch shader effect to entire backdrop
						layer.enabled: true
						layer.effect: GlitchEffect {
							chromatic: root.chromaticAberration
							displacement: root.shaderDisplacement
							noiseAmount: root.baselineNoise + root.glitchNoiseBurst + root.noiseAmount
							scanlineAlpha: root.scanlineAlpha
						}

						Image {
							anchors.fill: parent
							source: patternResolver.resolve(root.pattern)
							fillMode: Image.PreserveAspectCrop
							opacity: root.pattern !== "" ? 0.16 : 0.0
							visible: root.pattern !== ""
							layer.enabled: true
							layer.effect: MultiEffect {
								maskEnabled: true
								maskSource: Rectangle {
									width: backdrop.width
									height: backdrop.height
									radius: backdrop.radius
									color: "white"
								}
							}
						}

						RowLayout {
							id: contentColumn
							anchors.left: parent.left
							anchors.right: parent.right
							anchors.top: parent.top
							anchors.margins: 18
							spacing: 14

							// Free-floating image with color tint - height matches text container
							Image {
								id: accentImage
								Layout.preferredWidth: textColumn.height  // Square based on text height
								Layout.preferredHeight: textColumn.height
								Layout.alignment: Qt.AlignVCenter
								fillMode: Image.PreserveAspectFit
								source: imageResolver.resolve(root.imageVariant)
								opacity: 0.95
								smooth: true
								visible: source !== ""

								// Apply color tint based on severity
								layer.enabled: true
								layer.effect: ColorTintEffect {
									tintColor: root.tintColor
									intensity: 1.0
								}
							}

							Item {
								id: textColumn
								Layout.fillWidth: true
								Layout.minimumWidth: 280
								Layout.preferredHeight: Math.max(textContent.implicitHeight + 40, 140)
								implicitHeight: Layout.preferredHeight

								Rectangle {
									id: card
									anchors.fill: parent
									radius: 18
									color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.18)
									border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.6)
									border.width: 1.5
									clip: true

									ColumnLayout {
										id: textContent
										anchors.fill: parent
										anchors.margins: 20
										spacing: 10

										Text {
											text: root.title
											color: "#f8f8ff"
											font.pixelSize: 22
											font.bold: true
											font.family: "Source Code Pro"
											wrapMode: Text.Wrap
											Layout.fillWidth: true
											opacity: 0.96
										}

										Text {
											text: root.body
											color: "#d9e0ff"
											font.pixelSize: 17
											font.family: "Source Code Pro"
											wrapMode: Text.Wrap
											Layout.fillWidth: true
											opacity: 0.92
											lineHeight: 1.3
										}
									}
								}
							}
						}
					}
				}
			}

			// Entry animation with glitch effect and ripples
			SequentialAnimation {
				id: entryAnimation
				running: false

				ScriptAction {
					script: transitionEffect.start()
				}

				ParallelAnimation {
					NumberAnimation {
						target: panelContent
						property: "opacity"
						from: 0; to: 1
						duration: 320
						easing.type: Easing.OutCubic
					}

					SequentialAnimation {
						NumberAnimation {
							target: panelContent
							property: "scale"
							from: 0.88; to: 1.03
							duration: 200
							easing.type: Easing.OutCubic
						}
						NumberAnimation {
							target: panelContent
							property: "scale"
							from: 1.03; to: 1
							duration: 140
							easing.type: Easing.OutQuad
						}
					}

					SequentialAnimation {
						NumberAnimation {
							target: root
							property: "chromaticAberration"
							from: 0.045; to: 0.025
							duration: 120
							easing.type: Easing.OutQuad
						}
						NumberAnimation {
							target: root
							property: "chromaticAberration"
							from: 0.025; to: 0
							duration: 250
							easing.type: Easing.OutCubic
						}
					}

					SequentialAnimation {
						NumberAnimation {
							target: root
							property: "shaderDisplacement"
							from: -0.012; to: 0.008
							duration: 100
							easing.type: Easing.OutQuad
						}
						NumberAnimation {
							target: root
							property: "shaderDisplacement"
							from: 0.008; to: 0
							duration: 180
							easing.type: Easing.OutCubic
						}
					}

					SequentialAnimation {
						NumberAnimation {
							target: root
							property: "glitchNoiseBurst"
							from: 0; to: 0.04
							duration: 120
							easing.type: Easing.OutQuad
						}
						NumberAnimation {
							target: root
							property: "glitchNoiseBurst"
							from: 0.04; to: 0.10
							duration: 80
							easing.type: Easing.InOutQuad
						}
						NumberAnimation {
							target: root
							property: "glitchNoiseBurst"
							from: 0.10; to: 0.06
							duration: 100
							easing.type: Easing.InOutQuad
						}
						NumberAnimation {
							target: root
							property: "glitchNoiseBurst"
							from: 0.06; to: 0
							duration: 220
							easing.type: Easing.InQuad
						}
					}
				}
			}

			// Exit animation with glitch dissolve
			SequentialAnimation {
				id: exitAnimation
				running: false

				ParallelAnimation {
					NumberAnimation {
						target: panelContent
						property: "opacity"
						to: 0
						duration: 220
						easing.type: Easing.InCubic
					}

					NumberAnimation {
						target: panelContent
						property: "scale"
						to: 0.96
						duration: 220
						easing.type: Easing.InCubic
					}

					NumberAnimation {
						target: root
						property: "chromaticAberration"
						from: 0; to: 0.035
						duration: 220
						easing.type: Easing.InQuad
					}

					NumberAnimation {
						target: root
						property: "shaderDisplacement"
						from: 0; to: 0.015
						duration: 220
						easing.type: Easing.InQuad
					}

					NumberAnimation {
						target: root
						property: "noiseAmount"
						from: 0; to: 0.15
						duration: 220
						easing.type: Easing.InQuad
					}
				}

				ScriptAction {
					script: {
						root.visiblePopup = false;
						root.chromaticAberration = 0;
						root.shaderDisplacement = 0;
						root.noiseAmount = 0;
						root.glitchNoiseBurst = 0;
						transitionEffect.stop();
					}
				}
			}

			Timer {
				id: glitchTimer
				interval: 4200
				running: root.visiblePopup && !exitAnimation.running
				repeat: true
				onTriggered: idleGlitchAnimation.restart()
			}

			SequentialAnimation {
				id: idleGlitchAnimation
				running: false

				ParallelAnimation {
					NumberAnimation { target: root; property: "chromaticAberration"; from: 0; to: 0.008; duration: 100; easing.type: Easing.OutQuad }
					NumberAnimation { target: root; property: "shaderDisplacement"; from: 0; to: -0.003; duration: 100; easing.type: Easing.OutQuad }
					NumberAnimation { target: root; property: "glitchNoiseBurst"; from: 0; to: 0.03; duration: 100; easing.type: Easing.OutQuad }
				}

				ParallelAnimation {
					NumberAnimation { target: root; property: "chromaticAberration"; from: 0.008; to: 0.022; duration: 60; easing.type: Easing.InOutQuad }
					NumberAnimation { target: root; property: "shaderDisplacement"; from: -0.003; to: -0.008; duration: 60; easing.type: Easing.InOutQuad }
					NumberAnimation { target: root; property: "glitchNoiseBurst"; from: 0.03; to: 0.07; duration: 60; easing.type: Easing.InOutQuad }
				}

				ParallelAnimation {
					NumberAnimation { target: root; property: "chromaticAberration"; from: 0.022; to: 0.015; duration: 70; easing.type: Easing.InOutQuad }
					NumberAnimation { target: root; property: "shaderDisplacement"; from: -0.008; to: 0.005; duration: 70; easing.type: Easing.InOutQuad }
					NumberAnimation { target: root; property: "glitchNoiseBurst"; from: 0.07; to: 0.05; duration: 70; easing.type: Easing.InOutQuad }
				}

				ParallelAnimation {
					NumberAnimation { target: root; property: "chromaticAberration"; from: 0.015; to: 0; duration: 180; easing.type: Easing.InQuad }
					NumberAnimation { target: root; property: "shaderDisplacement"; from: 0.005; to: 0; duration: 180; easing.type: Easing.InQuad }
					NumberAnimation { target: root; property: "glitchNoiseBurst"; from: 0.05; to: 0; duration: 180; easing.type: Easing.InQuad }
				}
			}

			Connections {
				target: root
				function onPopupVersionChanged() {
					panelContent.opacity = 0;
					panelContent.scale = 0.88;
					root.chromaticAberration = 0;
					root.shaderDisplacement = 0;
					root.noiseAmount = 0;
					root.glitchNoiseBurst = 0;
					transitionEffect.stop();
					entryAnimation.restart();
				}
				function onRequestExit() {
					exitAnimation.start();
				}
			}
		}
	}
}
