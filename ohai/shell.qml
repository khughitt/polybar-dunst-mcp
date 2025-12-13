import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick.Effects

Scope {
	id: root

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
		function forSeverity(severity) {
			if (severity === "crit") return "#ff6b6b";
			if (severity === "warn") return "#ffb86c";
			return "#7ad7ff";
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
	property color accentColor: "#7ad7ff"
	property int popupVersion: 0
	property real glitchShift: 0

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
			color: string
		): void {
			root.title = title || body;
			root.body = body;
			root.severity = severity || "info";
			root.pattern = pattern || "";
			root.imageVariant = image || "ghost";
			root.accentColor = accentPicker.resolved(color, root.severity);
			root.timeoutSeconds = timeoutSeconds > 0 ? timeoutSeconds : 8;
			root.workspace = workspace || "";
			root.app = app || "";
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
			root.visiblePopup = false;
		}
	}

	// Hide after timeout
	Timer {
		id: hideTimer
		interval: root.timeoutSeconds * 1000
		onTriggered: root.visiblePopup = false
	}

	LazyLoader {
		active: root.visiblePopup

		PanelWindow {
			id: window
			anchors.right: true
			anchors.bottom: true
			margins.right: 24
			margins.bottom: 24
			implicitWidth: 480
			implicitHeight: Math.min(contentColumn.implicitHeight + 48, 720)
			exclusiveZone: 0
			color: "transparent"
			mask: Region {}

			Item {
				id: panelContent
				anchors.fill: parent
				opacity: 0
				scale: 0.95
				focus: true
				Keys.onEscapePressed: root.visiblePopup = false
				Keys.onPressed: {
					if (event.key === Qt.Key_QuoteLeft) {
						if (root.workspace !== "") {
							const cmd = ["hyprctl", "dispatch", "workspace", root.workspace];
							Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + '; running: true }', root);
						} else if (root.app !== "") {
							const cmd = ["hyprctl", "dispatch", "focuswindow", "title:" + root.app];
							Qt.createQmlObject('import Quickshell.Io; Process { command: ' + JSON.stringify(cmd) + '; running: true }', root);
						}
						root.visiblePopup = false;
					}
				}

				Item {
					anchors.fill: parent

					Rectangle {
						id: backdrop
						anchors.fill: parent
						radius: 20
						color: "#1a10182a"
						border.color: Qt.tint("#40ffffff", Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.45))
						border.width: 1.5
						clip: true
						visible: true

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

							Item {
								id: imageFrame
								Layout.preferredWidth: 150
								Layout.preferredHeight: 150
								Layout.alignment: Qt.AlignTop
								implicitHeight: Layout.preferredHeight

								Rectangle {
									id: imageCanvas
									anchors.fill: parent
									anchors.margins: 0
									radius: 16
									color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.16)
									border.width: 0
									clip: true

									Image {
										id: accentImage
										anchors.fill: parent
										anchors.margins: 12
										fillMode: Image.PreserveAspectFit
										source: imageResolver.resolve(root.imageVariant)
										opacity: 0.95
										smooth: true
										visible: source !== ""
									}
								}
							}

							Item {
								id: textColumn
								Layout.fillWidth: true
								Layout.preferredHeight: Math.max(textContent.implicitHeight + 40, 140)
								implicitHeight: Layout.preferredHeight

								Rectangle {
									id: card
									anchors.fill: parent
									radius: 18
									color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.08)
									border.color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.5)
									border.width: 1
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

			ParallelAnimation {
				id: entryAnimation
				running: false
				NumberAnimation {
					target: panelContent
					property: "opacity"
					from: 0
					to: 1
					duration: 260
					easing.type: Easing.OutCubic
				}
				SequentialAnimation {
					NumberAnimation {
						target: panelContent
						property: "scale"
						from: 0.92
						to: 1.02
						duration: 180
						easing.type: Easing.OutCubic
					}
					NumberAnimation {
						target: panelContent
						property: "scale"
						from: 1.02
						to: 1
						duration: 120
						easing.type: Easing.OutQuad
					}
				}
			}

			Timer {
				id: glitchTimer
				interval: 4200
				running: root.visiblePopup
				repeat: true
				onTriggered: glitchAnimation.restart()
			}

			SequentialAnimation {
				id: glitchAnimation
				running: false
				NumberAnimation {
					target: root
					property: "glitchShift"
					from: -6
					to: 6
					duration: 120
					easing.type: Easing.OutQuad
				}
				NumberAnimation {
					target: root
					property: "glitchShift"
					from: 6
					to: 0
					duration: 140
					easing.type: Easing.OutQuad
				}
			}

			Connections {
				target: root
				function onPopupVersionChanged() {
					panelContent.opacity = 0;
					panelContent.scale = 0.95;
					entryAnimation.restart();
				}
			}
		}
	}
}
