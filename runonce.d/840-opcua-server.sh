#!/bin/sh
# The tabular indentation is important for XML readability!

set -e
set -u

# Setting up the TF6100 OPC UA server
# Name of the OPC UA Data Access server instance
OPCUA_DA_NAME="MyOpcUaServer"
# ADS port of the TwinCAT PLC runtime (default: 851 for runtime 1)
OPCUA_DA_ADSPORT=851
# AMS NetID for the local PLC. Changes if you need access to remote PLC.
OPCUA_DA_AMSNETID="127.0.0.1.1.1"
# IP address used in OPC UA endpoint URIs
OPCUA_IP_ADDRESS="192.168.1.10"
# Set to true to allow unencrypted/unauthenticated OPC UA connections
OPCUA_SERVER_NONE_CERTIFICATE=false
# Set to true to allow anonymous OPC UA logins
OPCUA_USER_ANONYMOUS=false
# Set Administrator password for OPC UA server (default: 1)
OPCUA_ADMIN_PASSWORD="1"


echo "[840-opcua-server] INFO: Update TcUaDaConfig.xml file"
if ! pkg info | grep -q "^TF6100"; then
    echo "[840-opcua-server] ERROR: TF6100 package is not installed, cannot configure OPC UA server"
    exit 1
fi

if [ -f "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaDaConfig.xml" ]; then
    echo "[840-opcua-server] DEBUG: File exists: /usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaDaConfig.xml"
    sed -i '' \
        -e "s|<Name>.*</Name>|<Name>${OPCUA_DA_NAME}</Name>|" \
        -e "s|<AdsPort>.*</AdsPort>|<AdsPort>${OPCUA_DA_ADSPORT}</AdsPort>|" \
        -e "s|<AdsNetId>.*</AdsNetId>|<AdsNetId>${OPCUA_DA_AMSNETID}</AdsNetId>|" \
        "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaDaConfig.xml"
else
    echo "[840-opcua-server] ERROR: File does not exist: /usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaDaConfig.xml"
    exit 1
fi

echo "[840-opcua-server] INFO: Update TcUaServerConfig.xml file"
if [ -f "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaServerConfig.xml" ]; then
    echo "[840-opcua-server] DEBUG: File exists: /usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaServerConfig.xml"
    sed -i '' "s|\[NodeName\]|${OPCUA_IP_ADDRESS}|g" "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaServerConfig.xml"

    if [ "${OPCUA_SERVER_NONE_CERTIFICATE}" = "true" ]; then
        echo "[840-opcua-server] INFO: Adding security settings for None certificate"
        sed -i '' '/<\/UaEndpoint>/i\
         <SecuritySetting>\
            <SecurityPolicy>http://opcfoundation.org/UA/SecurityPolicy#None</SecurityPolicy>\
            <MessageSecurityMode>None</MessageSecurityMode>\
         </SecuritySetting>\
' "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaServerConfig.xml"
    fi
else
    echo "[840-opcua-server] ERROR: File does not exist: /usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaServerConfig.xml"
    exit 1
fi

echo "[840-opcua-server] INFO: Update TcUaSecurityConfig.xml file"
if [ ! -f "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaSecurityConfig.xml" ]; then
    echo "[840-opcua-server] WARNING: TcUaSecurityConfig.xml did not exist, creating a new one"
cat > "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaSecurityConfig.xml" <<EOF
<?xml version="1.0"?>
<TcUaSecurityConfig xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Groups>
        <Group Name="Guests" Access="0x0">
            <DefaultAccess Namespace="http://opcfoundation.org/UA/" Access="0xB" />
        </Group>
        <Group Name="Users" MemberOf="Guests" Access="0x0">
            <DefaultAccess Namespace="urn:${OPCUA_IP_ADDRESS}:BeckhoffAutomation:TcOpcUaServer:1" Access="0x11B" />
            <DefaultAccess Namespace="http://opcfoundation.org/UA/DI/" Access="0x11B" />
            <DefaultAccess Namespace="http://PLCopen.org/OpcUa/IEC61131-3/" Access="0x11B" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:Types:GlobalTypes" Access="0x11B" />
            <DefaultAccess Namespace="http://Beckhoff.com/TwinCAT/TF6100/Server/Configuration" Access="0xB" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:AC" Access="0x11B" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:${OPCUA_DA_NAME}" Access="0x3FF" />
        </Group>
        <Group Name="Administrators" MemberOf="Users" Access="0x0">
            <DefaultAccess Namespace="*" Access="0x3FF" />
        </Group>
    </Groups>
    <Users>
        <User Name="Administrator" Auth="OS" Password="${OPCUA_ADMIN_PASSWORD}" IsRoot="true" MemberOf="Administrators" />
    </Users>
    <AccessInfos />
</TcUaSecurityConfig>
EOF
else
    echo "[840-opcua-server] INFO: TcUaSecurityConfig.xml did exist, updating users"
    sed -i '' '/<User /d' "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaSecurityConfig.xml"
    admin_line="        <User Name=\"Administrator\" Auth=\"OS\" Password=\"${OPCUA_ADMIN_PASSWORD}\" IsRoot=\"true\" MemberOf=\"Administrators\" />"
    sed -i '' "/<Users>/a\\
${admin_line}\\
" "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaSecurityConfig.xml"
fi

if [ "${OPCUA_USER_ANONYMOUS}" = "true" ]; then
    sed -i '' '/<Users>/a\
        <User Name="Anonymous" Auth="None" IsRoot="true" MemberOf="Users" />\
' "/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server/TcUaSecurityConfig.xml"
fi

echo "[840-opcua-server] INFO: Done updating OPC UA configurations"
