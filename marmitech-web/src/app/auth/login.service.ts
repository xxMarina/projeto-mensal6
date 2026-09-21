import { HttpClient } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { Observable, of, throwError } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class KeycloakService {
  private http = inject(HttpClient);

  fazerLogin(email: string, senha: String): Observable<any> {
    // Tenta autenticação no backend ou aceita caso o usuário exista
    return this.http.post(`${environment.apiUrl}/api/usuario/login`, { email, senha }).pipe();
  }

  getToken(): string | undefined {
    return localStorage.getItem('token') || undefined;
  }

  login(): void {}

  logout(): void {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
  }

  getUserRoles(): string[] {
    const cargo = this.getUserCargo();
    return [cargo];
  }

  hasRole(role: string): boolean {
    const cargo = this.getUserCargo();
    if (cargo === 'ADMIN') return true;
    return cargo === role;
  }

  getUsername(): string | undefined {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      try {
        const user = JSON.parse(userStr);
        return user.nome || user.email || userStr;
      } catch (e) {
        return userStr;
      }
    }
    return 'usuario_local';
  }

  isAuthenticated(): boolean {
    return !!localStorage.getItem('token') || !!localStorage.getItem('user');
  }

  getUserCargo(): string {
    const userStr = localStorage.getItem('user');
    if (userStr) {
      try {
        const user = JSON.parse(userStr);
        return user.cargo || '';
      } catch (e) {
        return '';
      }
    }
    return '';
  }

  getUsuarioCargo(): string {
    return this.getUserCargo();
  }
}