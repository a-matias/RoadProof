// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RoadProofAuthorization} from "./RoadProofAuthorization.sol";

/// @title RoadProofRegistry
/// @author RoadProof
/// @notice Registra revisiones técnicas vehiculares y verifica la integridad
///         de sus informes mediante hashes.
/// @dev Los informes completos se almacenan fuera de la blockchain.
///      Las autorizaciones se consultan en RoadProofAuthorization.

contract RoadProofRegistry {
    // ---------------------------------------------------------------
    // TIPOS DE DATOS
    // ---------------------------------------------------------------

    /// @notice Resultados posibles de una revisión técnica.

    enum Resultado {
        APTO,
        CONDICIONAL,
        RECHAZADO
    }

    /// @notice Información registrada de una revisión técnica.

    struct Revision {
        bytes32 informeHash;
        bytes32 vehiculoRefHash;
        bytes32 tallerId;
        Resultado resultado;
        address directorTecnico;
        uint256 timestamp;
    }

    // ---------------------------------------------------------------
    // ESTADO
    // ---------------------------------------------------------------

    /// @notice Contrato externo que administra las autorizaciones.
    RoadProofAuthorization public immutable contratoAutorizacion;

    /// @notice Información de cada revisión, identificada por su ID.
    mapping(bytes32 => Revision) public revisiones;

    /// @notice Indica si una revisión ya fue registrada.
    mapping(bytes32 => bool) public revisionExiste;

    // ---------------------------------------------------------------
    // ERRORES PERSONALIZADOS
    // ---------------------------------------------------------------

    /// @notice El identificador de revisión o taller no es válido.
    error IdentificadorInvalido();

    /// @notice Uno de los hashes requeridos es cero.
    error HashInvalido();

    /// @notice El director técnico no está autorizado para el taller.
    error DirectorTecnicoNoAutorizado();

    /// @notice La revisión ya fue registrada.
    error RevisionDuplicada();

    /// @notice La revisión solicitada no existe.
    error RevisionInexistente();

    /// @notice La dirección del contrato de autorización es inválida.
    error ContratoAutorizacionInvalido();

    // ---------------------------------------------------------------
    // EVENTOS
    // ---------------------------------------------------------------

    /// @notice Se emite al registrar una revisión técnica.
    /// @param revisionId Identificador único de la revisión.
    /// @param tallerId Identificador del taller.
    /// @param vehiculoRefHash Hash de la referencia del vehículo.
    /// @param directorTecnico Dirección del director técnico que registró.
    /// @param resultado Resultado de la revisión.
    /// @param informeHash Hash del informe registrado.
    /// @param timestamp Momento del registro en blockchain.

    event RevisionRegistrada(
        bytes32 indexed revisionId,
        bytes32 indexed tallerId,
        bytes32 vehiculoRefHash,
        address indexed directorTecnico,
        Resultado resultado,
        bytes32 informeHash,
        uint256 timestamp
    );

    // ---------------------------------------------------------------
    // CONSTRUCTOR
    // ---------------------------------------------------------------

    /// @notice Inicializa el registro y define el contrato de autorización.
    /// @param direccionAutorizacion Dirección de RoadProofAuthorization.
    /// @dev El desplegador se convierte en propietario inicial del registro.

    constructor(address direccionAutorizacion) {
        if (direccionAutorizacion == address(0) || direccionAutorizacion.code.length == 0) {
            revert ContratoAutorizacionInvalido();
        }
        contratoAutorizacion = RoadProofAuthorization(direccionAutorizacion);
    }

    // ---------------------------------------------------------------
    // REGISTRO DE REVISIONES
    // ---------------------------------------------------------------

    /// @notice Registra una revisión técnica vehicular.
    /// @dev Consulta RoadProofAuthorization para comprobar que el emisor
    ///      está autorizado para el taller indicado.
    ///      Los registros no pueden modificarse ni eliminarse.
    /// @param revisionId Identificador único de la revisión.
    /// @param informeHash Hash del informe de revisión.
    /// @param vehiculoRefHash Hash de una referencia del vehículo.
    /// @param tallerId Identificador del taller.
    /// @param resultado Resultado de la revisión técnica.

    function registrarRevision(
        bytes32 revisionId,
        bytes32 informeHash,
        bytes32 vehiculoRefHash,
        bytes32 tallerId,
        Resultado resultado
    ) external {
        if (revisionId == bytes32(0) || tallerId == bytes32(0)) {
            revert IdentificadorInvalido();
        }

        if (informeHash == bytes32(0) || vehiculoRefHash == bytes32(0)) {
            revert HashInvalido();
        }

        if (revisionExiste[revisionId]) {
            revert RevisionDuplicada();
        }

        // Interacción entre contratos: consulta al contrato de autorización.
        bool autorizado = contratoAutorizacion.estaAutorizado(tallerId, msg.sender);

        if (!autorizado) {
            revert DirectorTecnicoNoAutorizado();
        }

        // Efectos: guardar la revisión después de validar las condiciones.
        uint256 timestampRegistro = block.timestamp;

        revisionExiste[revisionId] = true;

        revisiones[revisionId] = Revision({
            informeHash: informeHash,
            vehiculoRefHash: vehiculoRefHash,
            tallerId: tallerId,
            resultado: resultado,
            directorTecnico: msg.sender,
            timestamp: timestampRegistro
        });

        emit RevisionRegistrada(
            revisionId, tallerId, vehiculoRefHash, msg.sender, resultado, informeHash, timestampRegistro
        );
    }

    // ---------------------------------------------------------------
    // VERIFICACIÓN DE INTEGRIDAD
    // ---------------------------------------------------------------

    /// @notice Comprueba si un hash coincide con el informe registrado.
    /// @dev La coincidencia no demuestra que el informe sea verdadero;
    ///      demuestra que coincide con el hash guardado en blockchain.
    /// @param revisionId Identificador de la revisión.
    /// @param hashCalculado Hash calculado del informe que se verifica.
    /// @return integro True si el hash coincide con el registrado.

    function verificarIntegridad(bytes32 revisionId, bytes32 hashCalculado) external view returns (bool integro) {
        if (!revisionExiste[revisionId]) {
            revert RevisionInexistente();
        }

        if (hashCalculado == bytes32(0)) {
            revert HashInvalido();
        }

        return revisiones[revisionId].informeHash == hashCalculado;
    }
}
