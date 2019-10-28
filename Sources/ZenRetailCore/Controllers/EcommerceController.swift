//
//  EcommerceController.swift
//  Webretail
//
//  Created by Gerardo Grisolini on 25/10/17.
//

import Foundation
import ZenNIO

class EcommerceController {
    
    private let repository: EcommerceProtocol
    private let registryRepository: RegistryProtocol

    init(router: Router) {
        self.repository = ZenIoC.shared.resolve() as EcommerceProtocol
        self.registryRepository = ZenIoC.shared.resolve() as RegistryProtocol

        router.get("/robots.txt") { req, res in
            let robots = """
User-agent: *
Disallow:

Sitemap: \(ZenRetail.config.serverUrl)/sitemap.xml
"""
            res.send(text: robots)
            res.completed()
        }
        
        router.get("/sitemap.xml") { request, response in
            request.eventLoop.execute {
                do {
                    var siteMapItems = [SitemapItem]()

                    /// PAGES
                    siteMapItems.append(
                        SitemapItem(
                            url: "\(ZenRetail.config.serverUrl)/home",
                            changeFrequency: .daily,
                            priority: 1.0
                        )
                    )
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/info", priority: 0.8))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/account", priority: 0.1))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/login", priority: 0.1))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/register", priority: 0.1))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/checkout", priority: 0.1))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/orders", priority: 0.1))
                    siteMapItems.append(SitemapItem(url: "\(ZenRetail.config.serverUrl)/basket", priority: 0.1))

                    /// CATEGORIES
                    let categories = try self.repository.getCategories()
                    for item in categories {
                        siteMapItems.append(
                            SitemapItem(
                                url: "\(ZenRetail.config.serverUrl)/category/\(item.categorySeo?.permalink ?? "")",
                                lastModified: Date(timeIntervalSinceReferenceDate: TimeInterval(item.categoryUpdated)),
                                changeFrequency: .weekly,
                                priority: 0.9
                            )
                        )
                    }

                    /// BRANDS
                    let brands = try self.repository.getBrands()
                    for item in brands {
                        siteMapItems.append(
                            SitemapItem(
                                url: "\(ZenRetail.config.serverUrl)/brand/\(item.brandSeo.permalink)",
                                lastModified: Date(timeIntervalSinceReferenceDate: TimeInterval(item.brandUpdated)),
                                changeFrequency: .weekly,
                                priority: 0.9
                            )
                        )
                        
                        /// PRODUCTS
                        let products = try self.repository.getProducts(brand: item.brandSeo.permalink)
                        for product in products {
                            siteMapItems.append(
                                SitemapItem(
                                    url: "\(ZenRetail.config.serverUrl)/product/\(product.productSeo?.permalink ?? "")",
                                    lastModified: Date(timeIntervalSinceReferenceDate: TimeInterval(product.productUpdated)),
                                    changeFrequency: .weekly,
                                    priority: 0.9
                                )
                            )
                        }

                    }
                    let siteMap = Sitemap(items: siteMapItems)
                    
                    response.addHeader(.contentType, value: "application/xml; charset=utf-8")
                    let data = siteMap.xmlString.data(using: .utf8)!
                    response.send(data: data)
                    response.completed()
                } catch {
                    response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
                }
            }
        }
        
        /// Guest Api
        router.get("/api/ecommerce/setting", handler: ecommerceCompanyHandlerGET)
        router.get("/api/ecommerce/category", handler: ecommerceCategoriesHandlerGET)
        router.get("/api/ecommerce/brand", handler: ecommerceBrandsHandlerGET)
        router.get("/api/ecommerce/new", handler: ecommerceNewsHandlerGET)
        router.get("/api/ecommerce/sale", handler: ecommerceSaleHandlerGET)
        router.get("/api/ecommerce/featured", handler: ecommerceFeaturedHandlerGET)
        router.get("/api/ecommerce/category/:name", handler: ecommerceCategoryHandlerGET)
        router.get("/api/ecommerce/brand/:name", handler: ecommerceBrandHandlerGET)
        router.get("/api/ecommerce/product/:name", handler: ecommerceProductHandlerGET)
        router.get("/api/ecommerce/search/:text", handler: ecommerceSearchHandlerGET)

        /// Registry Api
        router.get("/api/ecommerce/registry", handler: ecommerceRegistryHandlerGET)
        router.put("/api/ecommerce/registry", handler: ecommerceRegistryHandlerPUT)
        router.delete("/api/ecommerce/registry", handler: ecommerceRegistryHandlerDELETE)

        router.get("/api/baskets", handler: ecommerceBasketsHandlerGET)
        router.get("/api/ecommerce/basket", handler: ecommerceBasketHandlerGET)
        router.post("/api/ecommerce/basket", handler: ecommerceBasketHandlerPOST)
        router.put("/api/ecommerce/basket/:id", handler: ecommerceBasketHandlerPUT)
        router.delete("/api/ecommerce/basket/:id", handler: ecommerceBasketHandlerDELETE)

        router.get("/api/ecommerce/payment", handler: ecommercePaymentsHandlerGET)
        router.get("/api/ecommerce/shipping", handler: ecommerceShippingsHandlerGET)
        router.get("/api/ecommerce/shipping/:id/cost", handler: ecommerceShippingCostHandlerGET)

        router.get("/api/ecommerce/order", handler: ecommerceOrdersHandlerGET)
        router.get("/api/ecommerce/order/:id", handler: ecommerceOrderHandlerGET)
        router.get("/api/ecommerce/order/:id/items", handler: ecommerceOrderItemsHandlerGET)
        router.post("/api/ecommerce/order", handler: ecommerceOrderHandlerPOST)

        router.post("/api/register") { request, response in
            request.eventLoop.execute {
                guard let data = request.bodyData else {
                    response.completed(.badRequest)
                    return
                }
                
                do {
                    let account = try JSONDecoder().decode(Account.self, from: data)
                    let registry = Registry()
                    if registry.exists(account.username) {
                        response.completed(.notAcceptable)
                        return
                    }
                    registry.registryEmail = account.username
                    registry.registryPassword = account.password.encrypted
                    try registry.save { id in
                        registry.registryId = id as! Int
                    }
                    
                    let base64 = UUID().uuidString.data(using: .utf8)!.base64EncodedString()
                    request.session!.token = Token(bearer: base64)
                    request.session!.uniqueID = registry.registryId.description
                    
                    try response.send(json: request.session!.token!)
                    response.completed()
                } catch {
                    response.completed(.internalServerError)
                }
            }
        }
    }

    /// Company
    
    func ecommerceCompanyHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let settings = try self.repository.getSettings()
                try response.send(json: settings)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    /// Products

    func ecommerceCategoriesHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getCategories()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceBrandsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getBrands()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceNewsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getProductsNews()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceSaleHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getProductsDiscount()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceFeaturedHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getProductsFeatured()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceCategoryHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let name: String = request.getParam("name") else {
                    throw HttpError.badRequest
                }
                let items = try self.repository.getProducts(category: name)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceBrandHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let name: String = request.getParam("name") else {
                    throw HttpError.badRequest
                }
                let items = try self.repository.getProducts(brand: name)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceProductHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let name: String = request.getParam("name") else {
                    throw HttpError.badRequest
                }
                let items = try self.repository.getProduct(name: name)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceSearchHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let text: String = request.getParam("text") else {
                    throw HttpError.badRequest
                }
                let items = try self.repository.findProducts(text: text)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    /// Registry

    func ecommerceRegistryHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                let registry = try self.registryRepository.get(id: uniqueID)
                try response.send(json:registry)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceRegistryHandlerPUT(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                guard let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let registry = try JSONDecoder().decode(Registry.self, from: data)
                try self.registryRepository.update(id: uniqueID, item: registry)
                try response.send(json:registry)
                response.completed( .accepted)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceRegistryHandlerDELETE(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                try self.registryRepository.delete(id: uniqueID)
                response.completed( .noContent)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    /// Basket

    func ecommerceBasketsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getBaskets()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceBasketHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            guard let uniqueID = request.session?.uniqueID as? String , let id = Int(uniqueID) else {
                response.completed( .unauthorized)
                return
            }

            do {
                let items = try self.repository.getBasket(registryId: id)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceBasketHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            guard let uniqueID = request.session?.uniqueID as? String , let id = Int(uniqueID) else {
                response.completed( .unauthorized)
                return
            }

            do {
                guard let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let basket = try JSONDecoder().decode(Basket.self, from: data)
                basket.registryId = id
                
                let product = Product()
                try product.get(barcode: basket.basketBarcode)
                if product.productId == 0 {
                    response.completed( .notFound)
                    return
                }
                basket.basketProduct = product
                basket.basketPrice = product.productDiscount != nil
                    ? product.productDiscount!.discountPrice : product.productPrice.selling

                try self.repository.addBasket(item: basket)
                try response.send(json:basket)
                response.completed( .created)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceBasketHandlerPUT(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let id: Int = request.getParam("id"),
                    let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let basket = try JSONDecoder().decode(Basket.self, from: data)
                try self.repository.updateBasket(id: id, item: basket)
                try response.send(json: basket)
                response.completed( .accepted)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceBasketHandlerDELETE(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                guard let id: Int = request.getParam("id") else {
                    throw HttpError.badRequest
                }
                try self.repository.deleteBasket(id: id)
                response.completed( .noContent)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    /// Payment
    
    func ecommercePaymentsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getPayments()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    /// Shipping
    
    func ecommerceShippingsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            do {
                let items = try self.repository.getShippings()
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceShippingCostHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                guard let id :String = request.getParam("id") else {
                    throw HttpError.badRequest
                }
                let registry = try self.registryRepository.get(id: uniqueID)!
                let cost = self.repository.getShippingCost(id: id, registry: registry)
                try response.send(json:cost)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    /// Order
    
    func ecommerceOrdersHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                let items = try self.repository.getOrders(registryId: uniqueID)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
    
    func ecommerceOrderHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                guard let id: Int = request.getParam("id") else {
                    throw HttpError.badRequest
                }
                let item = try self.repository.getOrder(registryId: uniqueID, id: id)
                try response.send(json:item)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceOrderItemsHandlerGET(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String  ?? "0")!
            do {
                guard let id: Int = request.getParam("id") else {
                    throw HttpError.badRequest
                }
                let items = try self.repository.getOrderItems(registryId: uniqueID, id: id)
                try response.send(json:items)
                response.completed()
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }

    func ecommerceOrderHandlerPOST(request: HttpRequest, response: HttpResponse) {
        request.eventLoop.execute {
            let uniqueID = Int(request.session?.uniqueID as? String ?? "0")!
            do {
                guard let data = request.bodyData else {
                    throw HttpError.badRequest
                }
                let order = try JSONDecoder().decode(OrderModel.self, from: data)
                let item = try self.repository.addOrder(registryId: uniqueID, order: order)
                try response.send(json:item)
                response.completed( .created)
            } catch {
                response.badRequest(error: "\(request.head.uri) \(request.head.method): \(error)")
            }
        }
    }
}

