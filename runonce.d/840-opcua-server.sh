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
# Set to true to allow anonymous OPC UA logins with non-root Users permissions
OPCUA_USER_ANONYMOUS=false
# Set Administrator password for OPC UA server (default: 1)
OPCUA_ADMIN_PASSWORD="1"

OPCUA_CONFIG_DIR="/usr/local/etc/TwinCAT/Functions/TF6100-OPC-UA/FreeBSD/Server"
OPCUA_DA_CONFIG="${OPCUA_CONFIG_DIR}/TcUaDaConfig.xml"
OPCUA_SERVER_CONFIG="${OPCUA_CONFIG_DIR}/TcUaServerConfig.xml"
OPCUA_SECURITY_CONFIG="${OPCUA_CONFIG_DIR}/TcUaSecurityConfig.xml"

echo "[840-opcua-server] INFO: Update TcUaDaConfig.xml file"
case "${OPCUA_SERVER_NONE_CERTIFICATE}" in
    true|false) ;;
    *)
        echo "[840-opcua-server] ERROR: OPCUA_SERVER_NONE_CERTIFICATE must be true or false"
        exit 1
        ;;
esac

case "${OPCUA_USER_ANONYMOUS}" in
    true|false) ;;
    *)
        echo "[840-opcua-server] ERROR: OPCUA_USER_ANONYMOUS must be true or false"
        exit 1
        ;;
esac

xml_escape() {
    printf '%s' "$1" | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\&apos;/g"
}

sed_escape_replacement() {
    printf '%s' "$1" | sed \
        -e 's/\\/\\\\/g' \
        -e 's/&/\\&/g' \
        -e 's/|/\\|/g'
}

require_single_line() {
    value_name="$1"
    value="$2"
    line_break='
'
    carriage_return=$(printf '\r')

    case "${value}" in
        *"${line_break}"*|*"${carriage_return}"*)
            echo "[840-opcua-server] ERROR: ${value_name} must not contain line breaks"
            exit 1
            ;;
    esac
}

require_single_line "OPCUA_DA_NAME" "${OPCUA_DA_NAME}"
require_single_line "OPCUA_DA_ADSPORT" "${OPCUA_DA_ADSPORT}"
require_single_line "OPCUA_DA_AMSNETID" "${OPCUA_DA_AMSNETID}"
require_single_line "OPCUA_IP_ADDRESS" "${OPCUA_IP_ADDRESS}"
require_single_line "OPCUA_ADMIN_PASSWORD" "${OPCUA_ADMIN_PASSWORD}"

OPCUA_DA_NAME_XML=$(xml_escape "${OPCUA_DA_NAME}")
OPCUA_DA_ADSPORT_XML=$(xml_escape "${OPCUA_DA_ADSPORT}")
OPCUA_DA_AMSNETID_XML=$(xml_escape "${OPCUA_DA_AMSNETID}")
OPCUA_IP_ADDRESS_XML=$(xml_escape "${OPCUA_IP_ADDRESS}")
OPCUA_ADMIN_PASSWORD_XML=$(xml_escape "${OPCUA_ADMIN_PASSWORD}")

if ! pkg info | grep -q "^TF6100"; then
    echo "[840-opcua-server] ERROR: TF6100 package is not installed, cannot configure OPC UA server"
    exit 1
fi

if [ -f "${OPCUA_DA_CONFIG}" ]; then
    echo "[840-opcua-server] DEBUG: File exists: ${OPCUA_DA_CONFIG}"
    sed -i '' \
        -e "s|<Name>.*</Name>|<Name>$(sed_escape_replacement "${OPCUA_DA_NAME_XML}")</Name>|" \
        -e "s|<AdsPort>.*</AdsPort>|<AdsPort>$(sed_escape_replacement "${OPCUA_DA_ADSPORT_XML}")</AdsPort>|" \
        -e "s|<AdsNetId>.*</AdsNetId>|<AdsNetId>$(sed_escape_replacement "${OPCUA_DA_AMSNETID_XML}")</AdsNetId>|" \
        "${OPCUA_DA_CONFIG}"

    if ! grep -Fq "<Name>${OPCUA_DA_NAME_XML}</Name>" "${OPCUA_DA_CONFIG}" \
        || ! grep -Fq "<AdsPort>${OPCUA_DA_ADSPORT_XML}</AdsPort>" "${OPCUA_DA_CONFIG}" \
        || ! grep -Fq "<AdsNetId>${OPCUA_DA_AMSNETID_XML}</AdsNetId>" "${OPCUA_DA_CONFIG}"; then
        echo "[840-opcua-server] ERROR: TcUaDaConfig.xml is missing one or more expected elements"
        exit 1
    fi
else
    echo "[840-opcua-server] ERROR: File does not exist: ${OPCUA_DA_CONFIG}"
    exit 1
fi

echo "[840-opcua-server] INFO: Update TcUaServerConfig.xml file"
if [ -f "${OPCUA_SERVER_CONFIG}" ]; then
    echo "[840-opcua-server] DEBUG: File exists: ${OPCUA_SERVER_CONFIG}"
    sed -i '' "s|\[NodeName\]|$(sed_escape_replacement "${OPCUA_IP_ADDRESS_XML}")|g" "${OPCUA_SERVER_CONFIG}"

    if [ "${OPCUA_SERVER_NONE_CERTIFICATE}" = "true" ]; then
        if ! grep -Fq "http://opcfoundation.org/UA/SecurityPolicy#None" "${OPCUA_SERVER_CONFIG}"; then
            echo "[840-opcua-server] INFO: Adding security settings for None certificate"
            sed -i '' '/<\/UaEndpoint>/i\
         <SecuritySetting>\
            <SecurityPolicy>http://opcfoundation.org/UA/SecurityPolicy#None</SecurityPolicy>\
            <MessageSecurityMode>None</MessageSecurityMode>\
         </SecuritySetting>\
' "${OPCUA_SERVER_CONFIG}"
        else
            echo "[840-opcua-server] INFO: Security setting for None certificate already exists"
        fi
    fi
else
    echo "[840-opcua-server] ERROR: File does not exist: ${OPCUA_SERVER_CONFIG}"
    exit 1
fi

echo "[840-opcua-server] INFO: Update TcUaSecurityConfig.xml file"
if [ ! -f "${OPCUA_SECURITY_CONFIG}" ]; then
    echo "[840-opcua-server] WARNING: TcUaSecurityConfig.xml did not exist, creating a new one"
cat > "${OPCUA_SECURITY_CONFIG}" <<EOF
<?xml version="1.0"?>
<TcUaSecurityConfig xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <Groups>
        <Group Name="Guests" Access="0x0">
            <DefaultAccess Namespace="http://opcfoundation.org/UA/" Access="0xB" />
        </Group>
        <Group Name="Users" MemberOf="Guests" Access="0x0">
            <DefaultAccess Namespace="urn:${OPCUA_IP_ADDRESS_XML}:BeckhoffAutomation:TcOpcUaServer:1" Access="0x11B" />
            <DefaultAccess Namespace="http://opcfoundation.org/UA/DI/" Access="0x11B" />
            <DefaultAccess Namespace="http://PLCopen.org/OpcUa/IEC61131-3/" Access="0x11B" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:Types:GlobalTypes" Access="0x11B" />
            <DefaultAccess Namespace="http://Beckhoff.com/TwinCAT/TF6100/Server/Configuration" Access="0xB" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:AC" Access="0x11B" />
            <DefaultAccess Namespace="urn:BeckhoffAutomation:Ua:${OPCUA_DA_NAME_XML}" Access="0x3FF" />
        </Group>
        <Group Name="Administrators" MemberOf="Users" Access="0x0">
            <DefaultAccess Namespace="*" Access="0x3FF" />
        </Group>
    </Groups>
    <Users>
        <User Name="Administrator" Auth="OS" Password="${OPCUA_ADMIN_PASSWORD_XML}" IsRoot="true" MemberOf="Administrators" />
    </Users>
    <AccessInfos />
</TcUaSecurityConfig>
EOF
else
    echo "[840-opcua-server] INFO: TcUaSecurityConfig.xml did exist, updating users"
    if ! grep -Fq "<Users>" "${OPCUA_SECURITY_CONFIG}"; then
        echo "[840-opcua-server] ERROR: TcUaSecurityConfig.xml does not contain a Users section"
        exit 1
    fi

    sed -i '' '/<User[[:space:]].*Name="Administrator"/d' "${OPCUA_SECURITY_CONFIG}"
    sed -i '' '/<Users>/a\
        <User Name="Administrator" Auth="OS" Password="__OPCUA_ADMIN_PASSWORD__" IsRoot="true" MemberOf="Administrators" />\
' "${OPCUA_SECURITY_CONFIG}"
    sed -i '' "/Name=\"Administrator\"/s|__OPCUA_ADMIN_PASSWORD__|$(sed_escape_replacement "${OPCUA_ADMIN_PASSWORD_XML}")|" "${OPCUA_SECURITY_CONFIG}"
fi

sed -i '' '/<User[[:space:]].*Name="Anonymous"/d' "${OPCUA_SECURITY_CONFIG}"
if [ "${OPCUA_USER_ANONYMOUS}" = "true" ]; then
    sed -i '' '/<Users>/a\
        <User Name="Anonymous" Auth="None" IsRoot="false" MemberOf="Users" />\
' "${OPCUA_SECURITY_CONFIG}"
fi

echo "[840-opcua-server] INFO: Done updating OPC UA configurations"
