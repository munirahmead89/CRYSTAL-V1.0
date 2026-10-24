import 'package:crystal_messenger/core/errors/app_exceptions.dart';
import 'package:crystal_messenger/core/errors/error_handler.dart';
import 'package:crystal_messenger/core/errors/failure.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('guard', () {
    test('returns Right with the produced value', () {
      final result = guard<int>(() => 42);

      expect(result, isA<Right<Failure, int>>());
      expect(result.getRight().toNullable(), 42);
    });

    test('maps thrown errors to Left<Failure>', () {
      final result = guard<int>(() => throw const NetworkException('down'));

      expect(result, isA<Left<Failure, int>>());
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<NetworkFailure>());
    });

    test('falls back to UnknownFailure for unexpected errors', () {
      final result = guard<int>(() => throw StateError('boom'));

      expect(result, isA<Left<Failure, int>>());
      final failure = result.fold((l) => l, (r) => null);
      expect(failure, isA<UnknownFailure>());
    });
  });

  group('toFailure', () {
    test('maps 401 responses to AuthFailure', () {
      final requestOptions = RequestOptions(path: '/me');
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 401),
      );

      expect(toFailure(dioError), isA<AuthFailure>());
    });

    test('maps 5xx responses to ServerFailure', () {
      final requestOptions = RequestOptions(path: '/x');
      final dioError = DioException(
        type: DioExceptionType.badResponse,
        requestOptions: requestOptions,
        response: Response(requestOptions: requestOptions, statusCode: 503),
      );

      expect(toFailure(dioError), isA<ServerFailure>());
    });

    test('maps connection errors to NetworkFailure', () {
      final dioError = DioException(
        type: DioExceptionType.connectionError,
        requestOptions: RequestOptions(path: '/x'),
      );

      expect(toFailure(dioError), isA<NetworkFailure>());
    });

    test('maps timeouts to NetworkFailure', () {
      final dioError = DioException(
        type: DioExceptionType.connectionTimeout,
        requestOptions: RequestOptions(path: '/x'),
      );

      expect(toFailure(dioError), isA<NetworkFailure>());
    });

    test('maps AppException subclasses', () {
      expect(toFailure(const CacheException('c')), isA<CacheFailure>());
      expect(toFailure(const UnauthorizedException('u')), isA<AuthFailure>());
    });
  });
}
