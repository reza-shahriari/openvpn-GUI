import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import VPNManager 1.0

ApplicationWindow {
    id: window
    width: 1000
    height: 700
    visible: true
    title: "OpenVPN Manager"
    
    // Modern dark theme colors
    readonly property color bgPrimary: "#1e1e1e"
    readonly property color bgSecondary: "#252526"
    readonly property color bgTertiary: "#2d2d30"
    readonly property color textPrimary: "#cccccc"
    readonly property color textSecondary: "#858585"
    readonly property color accent: "#0078d4"
    readonly property color accentHover: "#005a9e"
    readonly property color success: "#4ec9b0"
    readonly property color warning: "#f48771"
    readonly property color error: "#f48771"
    readonly property color border: "#3e3e42"
    
    color: bgPrimary
    
    VPNManager {
        id: vpnManager
        
        onPing_complete: {
            pingButton.enabled = true
            pingButton.text = "Ping All Servers"
        }
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15
        
        // Header
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "OpenVPN Manager"
                font.pixelSize: 28
                font.bold: true
                color: textPrimary
                Layout.fillWidth: true
            }
            
            // Connection Status
            Rectangle {
                width: 12
                height: 12
                radius: 6
                color: {
                    if (vpnManager.connection_status === "connected") return success
                    if (vpnManager.connection_status === "connecting") return warning
                    return textSecondary
                }
            }
            
            Text {
                text: {
                    if (vpnManager.connection_status === "connected") return "Connected: " + vpnManager.connected_config_name
                    if (vpnManager.connection_status === "connecting") return "Connecting..."
                    return "Disconnected"
                }
                color: textPrimary
                font.pixelSize: 14
            }
        }
        
        // Action Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Button {
                id: addFileButton
                text: "➕ Add Config File"
                Layout.preferredWidth: 150
                onClicked: vpnManager.show_file_dialog()
                
                background: Rectangle {
                    color: parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                id: addFolderButton
                text: "📁 Add Config Folder"
                Layout.preferredWidth: 150
                onClicked: vpnManager.show_folder_dialog()
                
                background: Rectangle {
                    color: parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                id: pingButton
                text: "Ping All Servers"
                Layout.preferredWidth: 150
                enabled: vpnManager.configs.length > 0
                onClicked: {
                    enabled = false
                    text = "Pinging..."
                    vpnManager.ping_all()
                }
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return bgTertiary
                        return parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                    }
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                id: deleteAllButton
                text: "🗑️ Delete All"
                Layout.preferredWidth: 130
                enabled: vpnManager.configs.length > 0
                onClicked: vpnManager.request_delete_all()
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return bgTertiary
                        return parent.pressed ? error : (parent.hovered ? error : warning)
                    }
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                id: disconnectButton
                text: "Disconnect"
                Layout.preferredWidth: 120
                enabled: vpnManager.connection_status === "connected"
                onClicked: vpnManager.disconnect_vpn()
                
                background: Rectangle {
                    color: {
                        if (!parent.enabled) return bgTertiary
                        return parent.pressed ? warning : (parent.hovered ? warning : error)
                    }
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        // Best Server Indicator
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: bgSecondary
            radius: 4
            border.color: border
            border.width: 1
            visible: vpnManager.get_best_server() !== ""
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                
                Text {
                    text: "🏆 Best Server:"
                    color: textSecondary
                    font.pixelSize: 14
                }
                
                Text {
                    text: vpnManager.get_best_server()
                    color: success
                    font.pixelSize: 14
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
        }
        
        // Config List
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: bgSecondary
            radius: 4
            border.color: border
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0
                
                // Header
                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    color: bgTertiary
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        
                        Text {
                            text: "Config Name"
                            color: textSecondary
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 300
                        }
                        
                        Text {
                            text: "Latency"
                            color: textSecondary
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Text {
                            text: "Status"
                            color: textSecondary
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 100
                            horizontalAlignment: Text.AlignHCenter
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Text {
                            text: "Actions"
                            color: textSecondary
                            font.pixelSize: 12
                            font.bold: true
                            Layout.preferredWidth: 200
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
                
                // Config List
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    
                    ListView {
                        id: configList
                        model: vpnManager.configs
                        spacing: 2
                        
                        delegate: Rectangle {
                            width: configList.width
                            height: 60
                            color: {
                                if (vpnManager.connected_config_name === modelData.name) return bgTertiary
                                return mouseArea.containsMouse ? bgTertiary : "transparent"
                            }
                            
                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 15
                                
                                Text {
                                    text: modelData.name
                                    color: textPrimary
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 300
                                    elide: Text.ElideRight
                                }
                                
                                Text {
                                    text: {
                                        if (modelData.latency < 0) return "—"
                                        return modelData.latency.toFixed(0) + " ms"
                                    }
                                    color: {
                                        if (modelData.latency < 0) return textSecondary
                                        if (modelData.latency < 50) return success
                                        if (modelData.latency < 100) return textPrimary
                                        return warning
                                    }
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Text {
                                    text: {
                                        if (vpnManager.connected_config_name === modelData.name) return "● Connected"
                                        if (modelData.ping_success) return "✓ Online"
                                        if (modelData.latency < 0) return "—"
                                        return "✗ Offline"
                                    }
                                    color: {
                                        if (vpnManager.connected_config_name === modelData.name) return success
                                        if (modelData.ping_success) return success
                                        return textSecondary
                                    }
                                    font.pixelSize: 14
                                    Layout.preferredWidth: 100
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                
                                Item { Layout.fillWidth: true }
                                
                                RowLayout {
                                    Layout.preferredWidth: 200
                                    spacing: 10
                                    
                                    Button {
                                        text: vpnManager.connected_config_name === modelData.name ? "Disconnect" : "Connect"
                                        Layout.preferredWidth: 90
                                        enabled: vpnManager.connection_status !== "connecting"
                                        
                                        onClicked: {
                                            if (vpnManager.connected_config_name === modelData.name) {
                                                vpnManager.disconnect_vpn()
                                            } else {
                                                vpnManager.connect_vpn(modelData.name)
                                            }
                                        }
                                        
                                        background: Rectangle {
                                            color: {
                                                if (!parent.enabled) return bgTertiary
                                                if (vpnManager.connected_config_name === modelData.name) {
                                                    return parent.pressed ? warning : (parent.hovered ? warning : error)
                                                }
                                                return parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                                            }
                                            radius: 4
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.text
                                            color: parent.enabled ? "white" : textSecondary
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 12
                                        }
                                    }
                                    
                                    Button {
                                        text: "🗑"
                                        Layout.preferredWidth: 40
                                        
                                        onClicked: vpnManager.remove_config(modelData.name)
                                        
                                        background: Rectangle {
                                            color: parent.pressed ? bgTertiary : (parent.hovered ? bgTertiary : "transparent")
                                            radius: 4
                                        }
                                        
                                        contentItem: Text {
                                            text: parent.text
                                            color: textSecondary
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Password Dialog (sudo/system password)
    Rectangle {
        id: passwordDialog
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 1001
        
        MouseArea {
            anchors.fill: parent
            // Don't close on background click for password dialog
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 450
            height: 220
            color: bgSecondary
            radius: 8
            border.color: border
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "Password Required"
                    font.pixelSize: 18
                    font.bold: true
                    color: textPrimary
                }
                
                Text {
                    id: passwordMessage
                    text: ""
                    font.pixelSize: 14
                    color: textSecondary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                
                TextField {
                    id: passwordInput
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "Enter your password"
                    focus: passwordDialog.visible
                    
                    background: Rectangle {
                        color: bgTertiary
                        radius: 4
                        border.color: parent.activeFocus ? accent : border
                        border.width: 1
                    }
                    
                    color: textPrimary
                    font.pixelSize: 14
                    
                    Keys.onReturnPressed: {
                        if (passwordInput.text.length > 0) {
                            vpnManager.provide_password(passwordInput.text)
                            passwordInput.text = ""
                            passwordDialog.visible = false
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    
                    Button {
                        text: "Cancel"
                        Layout.preferredWidth: 100
                        onClicked: {
                            passwordInput.text = ""
                            passwordDialog.visible = false
                            vpnManager.cancel_password()
                        }
                        
                        background: Rectangle {
                            color: parent.pressed ? bgTertiary : (parent.hovered ? bgTertiary : "transparent")
                            radius: 4
                            border.color: border
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "OK"
                        Layout.preferredWidth: 100
                        enabled: passwordInput.text.length > 0
                        onClicked: {
                            vpnManager.provide_password(passwordInput.text)
                            passwordInput.text = ""
                            passwordDialog.visible = false
                        }
                        
                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return bgTertiary
                                return parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                            }
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "white" : textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        Connections {
            target: vpnManager
            function onPassword_requested(message) {
                passwordMessage.text = message
                passwordInput.text = ""
                passwordDialog.visible = true
                passwordInput.forceActiveFocus()
            }
            
            function onPassword_cancelled() {
                passwordDialog.visible = false
                passwordInput.text = ""
            }
        }
    }
    
    // VPN Credentials Dialog (username + VPN password)
    Rectangle {
        id: vpnCredentialsDialog
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 1001
        
        MouseArea {
            anchors.fill: parent
            // Don't close on background click
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 450
            height: 260
            color: bgSecondary
            radius: 8
            border.color: border
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                
                Text {
                    text: "VPN Credentials Required"
                    font.pixelSize: 18
                    font.bold: true
                    color: textPrimary
                }
                
                Text {
                    id: vpnCredentialsMessage
                    text: ""
                    font.pixelSize: 14
                    color: textSecondary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                
                TextField {
                    id: vpnUsernameInput
                    Layout.fillWidth: true
                    placeholderText: "VPN username"
                    
                    background: Rectangle {
                        color: bgTertiary
                        radius: 4
                        border.color: parent.activeFocus ? accent : border
                        border.width: 1
                    }
                    
                    color: textPrimary
                    font.pixelSize: 14
                }
                
                TextField {
                    id: vpnPasswordInput
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: "VPN password"
                    
                    background: Rectangle {
                        color: bgTertiary
                        radius: 4
                        border.color: parent.activeFocus ? accent : border
                        border.width: 1
                    }
                    
                    color: textPrimary
                    font.pixelSize: 14
                    
                    Keys.onReturnPressed: {
                        if (vpnUsernameInput.text.length > 0 && vpnPasswordInput.text.length > 0) {
                            vpnManager.provide_vpn_credentials(vpnUsernameInput.text, vpnPasswordInput.text)
                            vpnUsernameInput.text = ""
                            vpnPasswordInput.text = ""
                            vpnCredentialsDialog.visible = false
                        }
                    }
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    
                    Button {
                        text: "Cancel"
                        Layout.preferredWidth: 100
                        onClicked: {
                            vpnUsernameInput.text = ""
                            vpnPasswordInput.text = ""
                            vpnCredentialsDialog.visible = false
                            vpnManager.cancel_vpn_credentials()
                        }
                        
                        background: Rectangle {
                            color: parent.pressed ? bgTertiary : (parent.hovered ? bgTertiary : "transparent")
                            radius: 4
                            border.color: border
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "OK"
                        Layout.preferredWidth: 100
                        enabled: vpnUsernameInput.text.length > 0 && vpnPasswordInput.text.length > 0
                        onClicked: {
                            vpnManager.provide_vpn_credentials(vpnUsernameInput.text, vpnPasswordInput.text)
                            vpnUsernameInput.text = ""
                            vpnPasswordInput.text = ""
                            vpnCredentialsDialog.visible = false
                        }
                        
                        background: Rectangle {
                            color: {
                                if (!parent.enabled) return bgTertiary
                                return parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                            }
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "white" : textSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        Connections {
            target: vpnManager
            function onVpn_credentials_requested(nameOrFolder) {
                if (nameOrFolder === "folder") {
                    vpnCredentialsMessage.text = "Enter VPN username and password to be used for all configs in the selected folder."
                } else {
                    vpnCredentialsMessage.text = "Enter VPN username and password for config: " + nameOrFolder
                }
                vpnUsernameInput.text = ""
                vpnPasswordInput.text = ""
                vpnCredentialsDialog.visible = true
                vpnUsernameInput.forceActiveFocus()
            }
            
            function onVpn_credentials_cancelled() {
                vpnCredentialsDialog.visible = false
                vpnUsernameInput.text = ""
                vpnPasswordInput.text = ""
            }
        }
    }
    
    // Delete All Confirmation Dialog
    Rectangle {
        id: deleteAllDialog
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 1002
        
        MouseArea {
            anchors.fill: parent
            onClicked: deleteAllDialog.visible = false
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 450
            height: 200
            color: bgSecondary
            radius: 8
            border.color: border
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                
                Text {
                    text: "Delete All Configs?"
                    font.pixelSize: 18
                    font.bold: true
                    color: error
                }
                
                Text {
                    id: deleteAllMessage
                    text: "Are you sure you want to delete all config files? This action cannot be undone."
                    font.pixelSize: 14
                    color: textPrimary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    
                    Button {
                        text: "Cancel"
                        Layout.preferredWidth: 100
                        onClicked: deleteAllDialog.visible = false
                        
                        background: Rectangle {
                            color: parent.pressed ? bgTertiary : (parent.hovered ? bgTertiary : "transparent")
                            radius: 4
                            border.color: border
                            border.width: 1
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "Delete All"
                        Layout.preferredWidth: 100
                        onClicked: {
                            vpnManager.delete_all_configs()
                            deleteAllDialog.visible = false
                        }
                        
                        background: Rectangle {
                            color: parent.pressed ? error : (parent.hovered ? error : warning)
                            radius: 4
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        Connections {
            target: vpnManager
            function onConfirm_delete_all(count) {
                deleteAllMessage.text = "Are you sure you want to delete all " + count + " config file(s)? This action cannot be undone."
                deleteAllDialog.visible = true
            }
        }
    }
    
    // Error Dialog
    Rectangle {
        id: errorDialog
        anchors.fill: parent
        color: "#80000000"
        visible: false
        z: 1000
        
        MouseArea {
            anchors.fill: parent
            onClicked: errorDialog.visible = false
        }
        
        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: 150
            color: bgSecondary
            radius: 8
            border.color: border
            border.width: 1
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                
                Text {
                    text: "Error"
                    font.pixelSize: 18
                    font.bold: true
                    color: error
                }
                
                Text {
                    id: errorText
                    text: ""
                    font.pixelSize: 14
                    color: textPrimary
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
                
                Button {
                    text: "OK"
                    Layout.alignment: Qt.AlignRight
                    onClicked: errorDialog.visible = false
                    
                    background: Rectangle {
                        color: parent.pressed ? accentHover : (parent.hovered ? accentHover : accent)
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        
        Connections {
            target: vpnManager
            function onError_occurred(message) {
                errorText.text = message
                errorDialog.visible = true
            }
        }
    }
}
