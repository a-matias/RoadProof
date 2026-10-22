// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RoadProofRegistry} from "../src/RoadProofRegistry.sol";
import {RoadProofAuthorization} from "../src/RoadProofAuthorization.sol";

contract RoadProofRegistryTest is Test {
    RoadProofAuthorization internal authorization;
    RoadProofRegistry internal registry;

    address internal directorTecnico;
    address internal usuarioNoAutorizado;

    bytes32 internal tallerId;
    bytes32 internal revisionId;
    bytes32 internal informeHash;
    bytes32 internal vehiculoRefHash;

    function setUp() public {
        authorization = new RoadProofAuthorization();
        registry = new RoadProofRegistry(address(authorization));

        directorTecnico = makeAddr("directorTecnico");
        usuarioNoAutorizado = makeAddr("usuarioNoAutorizado");

        tallerId = keccak256("TALLER_001");
        revisionId = keccak256("REVISION_001");
        informeHash = keccak256("HASH_INFORME_001");
        vehiculoRefHash = keccak256("VEHICULO_001");
    }

    // ---------------------------------------------------------------
    // AUTORIZACIONES
    // ---------------------------------------------------------------

    function testPropietarioPuedeAutorizarDirector() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        assertTrue(authorization.estaAutorizado(tallerId, directorTecnico));
    }

    function testUsuarioNoAutorizadoNoPuedeAutorizarDirector() public {
        vm.prank(usuarioNoAutorizado);
        vm.expectRevert();

        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);
    }

    function testNoPermiteAutorizarConTallerInvalido() public {
        vm.expectRevert(RoadProofAuthorization.IdentificadorInvalido.selector);

        authorization.autorizarDirectorTecnico(bytes32(0), directorTecnico);
    }

    function testNoPermiteAutorizarDireccionCero() public {
        vm.expectRevert(RoadProofAuthorization.DireccionInvalida.selector);

        authorization.autorizarDirectorTecnico(tallerId, address(0));
    }

    function testNoPermiteAutorizarDirectorDuplicado() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.expectRevert(RoadProofAuthorization.DirectorYaAutorizado.selector);

        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);
    }

    function testNoPermiteRevocarDirectorNoAutorizado() public {
        vm.expectRevert(RoadProofAuthorization.DirectorNoAutorizado.selector);

        authorization.revocarDirectorTecnico(tallerId, directorTecnico);
    }

    function testEmiteEventoAlAutorizarDirector() public {
        vm.expectEmit(true, true, true, true, address(authorization));

        emit RoadProofAuthorization.DirectorTecnicoAutorizado(tallerId, directorTecnico, address(this));

        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);
    }

    function testEmiteEventoAlRevocarDirector() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.expectEmit(true, true, true, true, address(authorization));

        emit RoadProofAuthorization.DirectorTecnicoRevocado(tallerId, directorTecnico, address(this));

        authorization.revocarDirectorTecnico(tallerId, directorTecnico);
    }

    function testConsultarDirectorNoAutorizadoDevuelveFalse() public view {
        assertFalse(authorization.estaAutorizado(tallerId, directorTecnico));
    }

    function testConsultarConTallerInvalidoRevierte() public {
        vm.expectRevert(RoadProofAuthorization.IdentificadorInvalido.selector);

        authorization.estaAutorizado(bytes32(0), directorTecnico);
    }

    function testConsultarConDireccionCeroRevierte() public {
        vm.expectRevert(RoadProofAuthorization.DireccionInvalida.selector);

        authorization.estaAutorizado(tallerId, address(0));
    }

    // ---------------------------------------------------------------
    // REGISTRO DE REVISIONES
    // ---------------------------------------------------------------

    function testDirectorAutorizadoPuedeRegistrarRevision() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);

        assertTrue(registry.revisionExiste(revisionId));

        assertTrue(registry.verificarIntegridad(revisionId, informeHash));
    }

    function testDirectorNoAutorizadoNoPuedeRegistrarRevision() public {
        vm.prank(usuarioNoAutorizado);
        vm.expectRevert(RoadProofRegistry.DirectorTecnicoNoAutorizado.selector);

        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);
    }

    function testNoPermiteRegistrarRevisionDuplicada() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        // Primera llamada: la revisión se registra correctamente.
        vm.prank(directorTecnico);
        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);

        // Segunda llamada: debe fallar porque el identificador ya existe.
        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.RevisionDuplicada.selector);

        registry.registrarRevision(
            revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.RECHAZADO
        );
    }

    function testDirectorRevocadoNoPuedeRegistrarRevision() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        authorization.revocarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.DirectorTecnicoNoAutorizado.selector);

        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);
    }

    function testNoPermiteRegistrarConRevisionInvalida() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.IdentificadorInvalido.selector);

        registry.registrarRevision(bytes32(0), informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);
    }

    function testNoPermiteRegistrarConTallerInvalido() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.IdentificadorInvalido.selector);

        registry.registrarRevision(
            revisionId, informeHash, vehiculoRefHash, bytes32(0), RoadProofRegistry.Resultado.APTO
        );
    }

    function testNoPermiteRegistrarConHashDeInformeCero() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.HashInvalido.selector);

        registry.registrarRevision(revisionId, bytes32(0), vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);
    }

    function testNoPermiteRegistrarConHashDeVehiculoCero() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        vm.expectRevert(RoadProofRegistry.HashInvalido.selector);

        registry.registrarRevision(revisionId, informeHash, bytes32(0), tallerId, RoadProofRegistry.Resultado.APTO);
    }

    function testEmiteEventoAlRegistrarRevision() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.expectEmit(true, true, true, true, address(registry));

        emit RoadProofRegistry.RevisionRegistrada(
            revisionId,
            tallerId,
            vehiculoRefHash,
            directorTecnico,
            RoadProofRegistry.Resultado.APTO,
            informeHash,
            block.timestamp
        );

        vm.prank(directorTecnico);
        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);
    }

    // ---------------------------------------------------------------
    // INTEGRIDAD DEL INFORME
    // ---------------------------------------------------------------

    function testDetectaHashDeInformeIncorrecto() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);

        bytes32 hashIncorrecto = keccak256("HASH_INCORRECTO");

        assertFalse(registry.verificarIntegridad(revisionId, hashIncorrecto));
    }

    function testNoPermiteVerificarRevisionInexistente() public {
        vm.expectRevert(RoadProofRegistry.RevisionInexistente.selector);

        registry.verificarIntegridad(keccak256("REVISION_INEXISTENTE"), informeHash);
    }

    function testNoPermiteVerificarConHashCero() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        vm.prank(directorTecnico);
        registry.registrarRevision(revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.APTO);

        vm.expectRevert(RoadProofRegistry.HashInvalido.selector);

        registry.verificarIntegridad(revisionId, bytes32(0));
    }

    // ---------------------------------------------------------------
    // INTEGRACION ENTRE CONTRATOS
    // ---------------------------------------------------------------

    function testRegistryConsultaAutorizacionExterna() public {
        authorization.autorizarDirectorTecnico(tallerId, directorTecnico);

        assertEq(address(registry.contratoAutorizacion()), address(authorization));

        vm.prank(directorTecnico);
        registry.registrarRevision(
            revisionId, informeHash, vehiculoRefHash, tallerId, RoadProofRegistry.Resultado.CONDICIONAL
        );

        (
            bytes32 informeHashGuardado,
            bytes32 vehiculoRefHashGuardado,
            bytes32 tallerIdGuardado,
            RoadProofRegistry.Resultado resultadoGuardado,
            address directorGuardado,
            uint256 timestampGuardado
        ) = registry.revisiones(revisionId);

        assertEq(informeHashGuardado, informeHash);
        assertEq(vehiculoRefHashGuardado, vehiculoRefHash);
        assertEq(tallerIdGuardado, tallerId);
        assertEq(uint256(resultadoGuardado), uint256(RoadProofRegistry.Resultado.CONDICIONAL));
        assertEq(directorGuardado, directorTecnico);
        assertGt(timestampGuardado, 0);
    }

    function testNoPermiteCrearRegistryConAutorizacionCero() public {
        vm.expectRevert(RoadProofRegistry.ContratoAutorizacionInvalido.selector);

        new RoadProofRegistry(address(0));
    }

    function testNoPermiteCrearRegistryConDireccionSinCodigo() public {
        address direccionSinContrato = makeAddr("direccionSinContrato");

        vm.expectRevert(RoadProofRegistry.ContratoAutorizacionInvalido.selector);

        new RoadProofRegistry(direccionSinContrato);
    }
}
