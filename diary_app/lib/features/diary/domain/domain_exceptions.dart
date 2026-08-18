sealed class DomainException {
  final String message;
  const DomainException(this.message);
}

final class ValidationException extends DomainException {
  const ValidationException(super.message);
}

final class NotFoundException extends DomainException {
  const NotFoundException(super.message);
}

final class RepositoryException extends DomainException {
  const RepositoryException(super.message);
}
